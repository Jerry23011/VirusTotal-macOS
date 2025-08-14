//
//  FileBatchViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2025-07-10.
//

import Foundation
import SwiftUI
import CryptoKit
@preconcurrency import QuickLookThumbnailing

@MainActor
@Observable
final class BatchFile: Identifiable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let fileSize: Int64
    let sha256: String

    var status: BatchFileStatus = .pending
    var uploadProgress: Double = 0.0
    var analysisStats: FileAnalysisStats?
    var typeDescription: String?
    var lastAnalysisDate: String?
    var reputation: Int?
    var uniqueSources: Int?
    var errorMessage: String?
    var thumbnailImage: NSImage?

    init(fileURL: URL, fileName: String, fileSize: Int64, sha256: String) {
        self.fileURL = fileURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256 = sha256
    }
}

enum BatchFileStatus {
    case pending
    case preparing
    case upload
    case uploading
    case analyzing
    case success
    case failed
}

// MARK: - FileBatchViewModel

@MainActor
@Observable
final class FileBatchViewModel {
    static let shared = FileBatchViewModel()

    var batchFiles: [BatchFile] = []
    var isProcessing: Bool = false
    var completedCount: Int = 0
    var overallProgress: Double = 0.0

    private var processingTasks: [UUID: Task<Void, Never>] = [:]
    private let maxConcurrentUploads = 3
    private var currentConcurrentUploads = 0

    init() {}

    // MARK: - Public Methods

    func addFiles(_ urls: [URL]) async {
        for url in urls {
            _ = url.startAccessingSecurityScopedResource()

            // Check if file already exists
            let fileName = url.lastPathComponent
            if batchFiles.contains(where: { $0.fileName == fileName }) {
                continue
            }

            // Validate file size
            let fileSize = getFileSize(for: url)
            guard fileSize > 0 && fileSize < 681_574_400 else {
                log.error("File \(fileName) exceeds size limit or is invalid")
                continue
            }

            // Calculate SHA256
            guard let sha256 = getFileSHA256(for: url) else {
                log.error("Failed to calculate SHA256 for \(fileName)")
                continue
            }

            // Create batch file
            let batchFile = BatchFile(
                fileURL: url,
                fileName: fileName,
                fileSize: fileSize,
                sha256: sha256
            )

            batchFiles.append(batchFile)

            // Generate thumbnail asynchronously
            Task {
                await generateThumbnail(for: batchFile)
            }
        }
    }

    func removeFile(_ batchFile: BatchFile) {
        // Cancel processing if in progress
        if let task = processingTasks[batchFile.id] {
            task.cancel()
            processingTasks.removeValue(forKey: batchFile.id)
        }

        batchFiles.removeAll { $0.id == batchFile.id }
        updateProgress()
    }

    func clearAllFiles() {
        cancelAllProcessing()
        batchFiles.removeAll()
        resetProgress()
        resetAllFileStatuses()
    }

    private func resetAllFileStatuses() {
        for batchFile in batchFiles {
            batchFile.status = .pending
            batchFile.errorMessage = nil
            batchFile.uploadProgress = 0.0
        }
    }

    func startBatchAnalysis() async {
        guard !isProcessing else { return }

        isProcessing = true
        resetProgress()

        // Reset all file statuses
        for batchFile in batchFiles {
            batchFile.status = .pending
            batchFile.errorMessage = nil
        }

        // Start processing files with concurrency control
        await withTaskGroup(of: Void.self) { group in
            for batchFile in batchFiles {
                group.addTask {
                    await self.processFile(batchFile)
                }
            }
        }

        isProcessing = false
    }

    func cancelAllProcessing() {
        isProcessing = false

        // Cancel all ongoing tasks
        for task in processingTasks.values {
            task.cancel()
        }
        processingTasks.removeAll()

        // Reset file statuses
        for batchFile in batchFiles {
            if batchFile.status == .uploading || batchFile.status == .analyzing {
                batchFile.status = .pending
            }
        }

        currentConcurrentUploads = 0
        resetProgress()
    }

    // MARK: - Private Methods

    private func processFile(_ batchFile: BatchFile) async {
        let task = Task {
            await processFileInternal(batchFile)
        }

        processingTasks[batchFile.id] = task
        await task.value
        processingTasks.removeValue(forKey: batchFile.id)
    }

    private func processFileInternal(_ batchFile: BatchFile) async {
        do {
            // First, check if file already exists in VirusTotal
            batchFile.status = .preparing
            let reportResult = try await FileAnalysis.shared.getFileReport(sha256: batchFile.sha256)

            if reportResult.getReportSuccess == true {
                // File exists, update with results
                updateBatchFileWithResults(batchFile, reportResult)
                batchFile.status = .success

                storeScanEntry(for: batchFile)

                await NotificationManager.pushNotification(title: String(localized: "notification.analysis.complete.title"))
                updateCompletedCount()
                return
            }

            // File doesn't exist, need to upload
            batchFile.status = .upload

            // Wait for upload slot
            await waitForUploadSlot()

            guard !Task.isCancelled else { return }

            // Upload file
            batchFile.status = .uploading
            currentConcurrentUploads += 1

            let uploadSuccess = try await uploadFile(batchFile)
            currentConcurrentUploads -= 1

            if uploadSuccess {
                batchFile.status = .analyzing

                // Wait for analysis to complete
                try await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds

                // Get analysis results with retry logic
                await getAnalysisResults(batchFile)
            } else {
                batchFile.status = .failed
                await NotificationManager.pushNotification(title: String(localized: "notification.upload.fail.title"))
                updateCompletedCount()
            }

        } catch {
            currentConcurrentUploads = max(0, currentConcurrentUploads - 1)
            batchFile.status = .failed
            batchFile.errorMessage = error.localizedDescription
            updateCompletedCount()
        }
    }

    private func waitForUploadSlot() async {
        while currentConcurrentUploads >= maxConcurrentUploads {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }

    private func uploadFile(_ batchFile: BatchFile) async throws -> Bool {
        var apiEndpoint = chooseUploadEndpoint(for: batchFile)

        // Get large file endpoint if needed
        if batchFile.fileSize > 33_554_432 {
            let endpointResult = try await FileAnalysis.shared.getLargeFileEndpoint()
            guard endpointResult.getEndpointSuccess == true,
                  let largeEndpoint = endpointResult.largeFileEndpoint else {
                log.error("Failed to get large file endpoint")
                return false
            }
            apiEndpoint = largeEndpoint
        }

        let progressHandler: @Sendable (Double) -> Void = { [weak batchFile] progress in
            Task { @MainActor in
                batchFile?.uploadProgress = progress
            }
        }

        let uploadResult = try await FileAnalysis.shared.uploadFile(
            fileURL: batchFile.fileURL,
            apiEndPoint: apiEndpoint,
            progressHandler: progressHandler
        )

        return uploadResult.uploadSuccess == true
    }

    private func getAnalysisResults(_ batchFile: BatchFile) async {
        var retryCount = 0
        let maxRetries = 28 // 28 * 10 seconds = ~5 minutes

        while retryCount < maxRetries {
            guard !Task.isCancelled else { return }

            do {
                let reportResult = try await FileAnalysis.shared.getFileReport(sha256: batchFile.sha256)

                if reportResult.getReportSuccess == true,
                   let stats = reportResult.lastAnalysisStats,
                   isValidResponse(stats) {
                    updateBatchFileWithResults(batchFile, reportResult)
                    batchFile.status = .success

                    storeScanEntry(for: batchFile)

                    await NotificationManager.pushNotification(title: String(localized: "notification.analysis.complete.title"))
                    updateCompletedCount()
                    return
                }

                if reportResult.getReportSuccess != true {
                    batchFile.status = .failed
                    batchFile.errorMessage = reportResult.errorMessage
                    return
                }

                // If analysis is still in progress, wait and retry
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                retryCount += 1

            } catch {
                batchFile.status = .failed
                await NotificationManager.pushNotification(title: String(localized: "notification.analysis.fail.title"))
                batchFile.errorMessage = error.localizedDescription
                updateCompletedCount()
                return
            }
        }

        // Timeout
        batchFile.status = .failed
        await NotificationManager.pushNotification(title: String(localized: "notification.analysis.fail.title"))
        batchFile.errorMessage = "Analysis timeout"
        updateCompletedCount()
    }

    private func updateBatchFileWithResults(_ batchFile: BatchFile, _ result: FileAnalysisResult) {
        batchFile.analysisStats = result.lastAnalysisStats
        batchFile.typeDescription = result.typeDescription
        batchFile.lastAnalysisDate = result.lastAnalysisDate
        batchFile.reputation = result.reputation
        batchFile.uniqueSources = result.uniqueSources
    }

    private func updateCompletedCount() {
        completedCount = batchFiles.filter {
            $0.status == .success || $0.status == .failed
        }.count
        updateProgress()
    }

    private func updateProgress() {
        let totalFiles = batchFiles.count
        guard totalFiles > 0 else {
            overallProgress = 0.0
            return
        }
        overallProgress = Double(completedCount) / Double(totalFiles)
    }

    private func resetProgress() {
        completedCount = 0
        overallProgress = 0.0
    }

    private func chooseUploadEndpoint(for batchFile: BatchFile) -> String {
        if batchFile.fileSize <= 33_554_432 {
            return "https://www.virustotal.com/api/v3/files"
        } else {
            return "https://www.virustotal.com/api/v3/files" // Will be replaced with large file endpoint
        }
    }

    private func isValidResponse(_ stats: FileAnalysisStats) -> Bool {
        return stats.allFlags.sum { $0 } > 0
    }

    private func generateThumbnail(for batchFile: BatchFile) async {
        let size = CGSize(width: 32, height: 32)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let request = QLThumbnailGenerator.Request(
            fileAt: batchFile.fileURL,
            size: size,
            scale: scale,
            representationTypes: .lowQualityThumbnail
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            batchFile.thumbnailImage = thumbnail.nsImage
        } catch {
            log.warning("Thumbnail generation failed for \(batchFile.fileName): \(error)")
        }
    }

    private func getFileSize(for fileURL: URL) -> Int64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return fileAttributes[.size] as? Int64 ?? 0
        } catch {
            log.error("Error getting file size: \(error)")
            return 0
        }
    }

    private func getFileSHA256(for fileURL: URL) -> String? {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let hash = SHA256.hash(data: fileData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

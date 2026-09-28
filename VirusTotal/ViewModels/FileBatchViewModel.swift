//
//  FileBatchViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2025-07-10.
//

import Foundation
import SwiftUI
import QuickLookThumbnailing

@MainActor
@Observable
final class BatchFile: Identifiable {
    let id = UUID()
    let originalFileURL: URL
    var preparedFileURL: URL
    var fileName: String
    var fileSize: Int64
    var sha256: String

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
        self.originalFileURL = fileURL
        self.preparedFileURL = fileURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.sha256 = sha256
    }
}

enum BatchFileStatus {
    case pending
    case preparingArchive
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
    var hasPreparingArchives: Bool {
        batchFiles.contains { $0.status == .preparingArchive }
    }

    private var processingTasks: [UUID: Task<Void, Never>] = [:]
    private var cancellationTokens: [UUID: FileAnalysisCancellationToken] = [:]
    private var securityScopedFileURLs: Set<URL> = []
    private let maxConcurrentUploads = 3
    private var currentConcurrentUploads = 0
    private var uploadGeneration = 0

    init() {}

    deinit {
        MainActor.assumeIsolated {
            for url in securityScopedFileURLs {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }

    // MARK: - Public Methods

    func addFiles(_ urls: [URL]) async {
        for url in urls {
            await addFile(url)
        }
    }

    func removeFile(_ batchFile: BatchFile) {
        // Cancel processing if in progress
        if let task = processingTasks[batchFile.id] {
            task.cancel()
            processingTasks.removeValue(forKey: batchFile.id)
        }
        cancellationTokens.removeValue(forKey: batchFile.id)?.cancelAll()

        FilePreparation.cleanupPreparedFile(at: batchFile.preparedFileURL)
        releaseSecurityScopedAccess(for: batchFile.originalFileURL)
        batchFiles.removeAll { $0.id == batchFile.id }
        updateProgress()
    }

    func clearAllFiles() {
        cancelAllProcessing()
        batchFiles.forEach { FilePreparation.cleanupPreparedFile(at: $0.preparedFileURL) }
        releaseAllSecurityScopedAccess()
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
        guard !isProcessing, !hasPreparingArchives else { return }

        isProcessing = true
        resetProgress()

        // Reset all file statuses
        for batchFile in batchFiles {
            batchFile.status = .pending
            batchFile.errorMessage = nil
            batchFile.uploadProgress = 0.0
        }

        // Start processing files with concurrency control
        await withTaskGroup(of: Void.self) { group in
            for batchFile in batchFiles {
                group.addTask {
                    await self.processFile(batchFile)
                }
            }
        }

        if processingTasks.isEmpty {
            isProcessing = false
        }
    }

    func cancelAllProcessing() {
        isProcessing = false

        // Cancel all ongoing tasks and their Alamofire requests.
        for task in processingTasks.values {
            task.cancel()
        }
        for token in cancellationTokens.values {
            token.cancelAll()
        }
        processingTasks.removeAll()
        cancellationTokens.removeAll()

        // Reset active file statuses without changing completed results.
        for batchFile in batchFiles {
            switch batchFile.status {
            case .preparingArchive, .preparing, .upload, .uploading, .analyzing:
                batchFile.status = .pending
                batchFile.uploadProgress = 0.0
            case .pending, .success, .failed:
                break
            }
        }

        uploadGeneration += 1
        currentConcurrentUploads = 0
        resetProgress()
    }

    // MARK: - Private Methods

    private struct FileInspection {
        let shouldShowPreparation: Bool
        let preparedFileName: String
    }

    private struct PreparedFileDetails {
        let fileURL: URL
        let fileName: String
        let fileSize: Int64
        let sha256: String
    }

    private enum FilePreparationFailure: Error {
        case local(Error)
        case invalidSize(fileName: String, fileSize: Int64)
        case sha256(fileName: String, fileSize: Int64)
    }

    private func addFile(_ url: URL) async {
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        guard let inspection = inspectFile(at: url) else {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            return
        }
        guard !isDuplicateFile(url, preparedFileName: inspection.preparedFileName) else {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            return
        }

        if didStartAccessing {
            securityScopedFileURLs.insert(url)
        }

        let batchFile = makeBatchFile(for: url)
        appendPreparingFileIfNeeded(batchFile, shouldShowPreparation: inspection.shouldShowPreparation)

        switch await prepareFileDetails(for: url) {
        case .success(let details):
            updatePreparedFile(
                batchFile,
                fileURL: details.fileURL,
                fileName: details.fileName,
                fileSize: details.fileSize,
                sha256: details.sha256
            )
        case .failure(let failure):
            applyPreparationFailure(failure, to: batchFile, originalURL: url)
        }
    }

    private func inspectFile(at url: URL) -> FileInspection? {
        do {
            return FileInspection(
                shouldShowPreparation: try FilePreparation.needsZipArchive(for: url),
                preparedFileName: try FilePreparation.preparedFileName(for: url)
            )
        } catch {
            appendFailedFile(
                fileName: url.lastPathComponent,
                fileSize: 0,
                message: "Local Error: \(error.displayMessageWithCode)"
            )
            log.error("Failed to inspect \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    private func isDuplicateFile(_ url: URL, preparedFileName: String) -> Bool {
        batchFiles.contains { $0.fileName == preparedFileName || $0.fileName == url.lastPathComponent }
    }

    private func makeBatchFile(for url: URL) -> BatchFile {
        BatchFile(
            fileURL: url,
            fileName: url.lastPathComponent,
            fileSize: 0,
            sha256: ""
        )
    }

    private func appendPreparingFileIfNeeded(_ batchFile: BatchFile, shouldShowPreparation: Bool) {
        guard shouldShowPreparation else { return }

        batchFile.status = .preparingArchive
        batchFiles.append(batchFile)
    }

    private func prepareFileDetails(for url: URL) async -> Result<PreparedFileDetails, FilePreparationFailure> {
        let scanFileURL: URL
        do {
            scanFileURL = try await FilePreparation.scanFileURL(for: url)
        } catch {
            log.error("Failed to prepare \(url.lastPathComponent): \(error)")
            return .failure(.local(error))
        }

        let fileName = scanFileURL.lastPathComponent
        let fileSize = getFileSize(for: scanFileURL)
        guard ScanPolicy.isSupportedFileSize(fileSize) else {
            log.error("File \(fileName) exceeds size limit or is invalid")
            FilePreparation.cleanupPreparedFile(at: scanFileURL)
            return .failure(.invalidSize(fileName: fileName, fileSize: fileSize))
        }

        do {
            let sha256 = try await getFileSHA256(for: scanFileURL)
            return .success(
                PreparedFileDetails(
                    fileURL: scanFileURL,
                    fileName: fileName,
                    fileSize: fileSize,
                    sha256: sha256
                )
            )
        } catch {
            log.error("Failed to calculate SHA256 for \(fileName)")
            FilePreparation.cleanupPreparedFile(at: scanFileURL)
            return .failure(.sha256(fileName: fileName, fileSize: fileSize))
        }
    }

    private func applyPreparationFailure(_ failure: FilePreparationFailure,
                                         to batchFile: BatchFile,
                                         originalURL: URL) {
        switch failure {
        case .local(let error):
            markFailed(
                batchFile,
                fallbackFileName: originalURL.lastPathComponent,
                message: "Local Error: \(error.displayMessageWithCode)"
            )
        case .invalidSize(let fileName, let fileSize):
            markFailed(
                batchFile,
                fallbackFileName: fileName,
                fileSize: fileSize,
                message: "File size exceeds 650 MB or is invalid"
            )
        case .sha256(let fileName, let fileSize):
            markFailed(
                batchFile,
                fallbackFileName: fileName,
                fileSize: fileSize,
                message: "Failed to calculate SHA256"
            )
        }
    }

    private func appendFailedFile(fileName: String, fileSize: Int64, message: String) {
        let batchFile = BatchFile(
            fileURL: URL(filePath: ""),
            fileName: fileName,
            fileSize: fileSize,
            sha256: ""
        )
        batchFile.errorMessage = message
        batchFile.status = .failed
        batchFiles.append(batchFile)
    }

    private func updatePreparedFile(_ batchFile: BatchFile,
                                    fileURL: URL,
                                    fileName: String,
                                    fileSize: Int64,
                                    sha256: String) {
        if !batchFiles.contains(where: { $0.id == batchFile.id }) {
            batchFiles.append(batchFile)
        }

        batchFile.preparedFileURL = fileURL
        batchFile.fileName = fileName
        batchFile.fileSize = fileSize
        batchFile.sha256 = sha256
        batchFile.status = .pending
        batchFile.errorMessage = nil

        Task {
            await generateThumbnail(for: batchFile)
        }
    }

    private func markFailed(_ batchFile: BatchFile,
                            fallbackFileName: String,
                            fileSize: Int64 = 0,
                            message: String) {
        if !batchFiles.contains(where: { $0.id == batchFile.id }) {
            batchFiles.append(batchFile)
        }

        batchFile.fileName = fallbackFileName
        batchFile.fileSize = fileSize
        batchFile.errorMessage = message
        batchFile.status = .failed
    }

    private func processFile(_ batchFile: BatchFile) async {
        let cancellationToken = FileAnalysisCancellationToken()
        let task = Task {
            await processFileInternal(batchFile, cancellationToken: cancellationToken)
        }

        processingTasks[batchFile.id] = task
        cancellationTokens[batchFile.id] = cancellationToken
        await task.value

        if cancellationTokens[batchFile.id] === cancellationToken {
            cancellationTokens.removeValue(forKey: batchFile.id)
            processingTasks.removeValue(forKey: batchFile.id)
        }
    }

    private func processFileInternal(_ batchFile: BatchFile, cancellationToken: FileAnalysisCancellationToken) async {
        do {
            try Task.checkCancellation()
            try await refreshPreparedFile(for: batchFile)
            defer {
                FilePreparation.cleanupPreparedFile(at: batchFile.preparedFileURL)
            }

            if try await handleExistingReport(for: batchFile, cancellationToken: cancellationToken) {
                return
            }

            try await uploadAndAnalyze(batchFile, cancellationToken: cancellationToken)
        } catch is CancellationError {
            if batchFiles.contains(where: { $0.id == batchFile.id }) {
                batchFile.status = .pending
                batchFile.uploadProgress = 0.0
            }
        } catch {
            batchFile.status = .failed
            batchFile.errorMessage = error.displayMessageWithCode
            log.error(batchFile.errorMessage ?? "Unknown Error")
            updateCompletedCount()
        }
    }

    private func handleExistingReport(for batchFile: BatchFile,
                                      cancellationToken: FileAnalysisCancellationToken) async throws -> Bool {
        try Task.checkCancellation()
        batchFile.status = .preparing
        let reportResult = try await FileAnalysis.shared.getFileReport(
            sha256: batchFile.sha256,
            cancellationToken: cancellationToken
        )
        try Task.checkCancellation()

        guard reportResult.statusMonitor != .fail else {
            batchFile.status = .failed
            batchFile.errorMessage = reportResult.errorMessage
            log.error(batchFile.errorMessage ?? "Unknown Error")
            return true
        }

        guard reportResult.getReportSuccess == true else { return false }
        guard let stats = reportResult.lastAnalysisStats, isValidResponse(stats) else {
            await getAnalysisResults(batchFile, cancellationToken: cancellationToken)
            return true
        }

        updateBatchFileWithResults(batchFile, reportResult)
        batchFile.status = .success
        storeScanEntry(for: batchFile)
        await NotificationManager.pushNotification(title: String(localized: "notification.analysis.complete.title"))
        updateCompletedCount()
        return true
    }

    private func uploadAndAnalyze(_ batchFile: BatchFile, cancellationToken: FileAnalysisCancellationToken) async throws {
        batchFile.status = .upload
        try await waitForUploadSlot()
        try Task.checkCancellation()

        batchFile.status = .uploading
        let generation = uploadGeneration
        currentConcurrentUploads += 1
        defer {
            if generation == uploadGeneration {
                currentConcurrentUploads = max(0, currentConcurrentUploads - 1)
            }
        }

        let uploadSuccess = try await uploadFile(batchFile, cancellationToken: cancellationToken)
        try Task.checkCancellation()

        guard uploadSuccess else {
            batchFile.status = .failed
            batchFile.errorMessage = "Upload Failed"
            log.error("Upload Failed")
            await NotificationManager.pushNotification(title: String(localized: "notification.upload.fail.title"))
            updateCompletedCount()
            return
        }

        batchFile.status = .analyzing
        try await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
        try Task.checkCancellation()
        await getAnalysisResults(batchFile, cancellationToken: cancellationToken)
    }

    private func waitForUploadSlot() async throws {
        while currentConcurrentUploads >= maxConcurrentUploads {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }

    private func refreshPreparedFile(for batchFile: BatchFile) async throws {
        if try FilePreparation.needsZipArchive(for: batchFile.originalFileURL) {
            batchFile.status = .preparingArchive
        }

        let scanFileURL = try await FilePreparation.scanFileURL(for: batchFile.originalFileURL)
        let fileName = scanFileURL.lastPathComponent
        let fileSize = getFileSize(for: scanFileURL)
        guard ScanPolicy.isSupportedFileSize(fileSize) else {
            FilePreparation.cleanupPreparedFile(at: scanFileURL)
            throw NSError(
                domain: "VirusTotal.FileBatchViewModel",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "File size exceeds 650 MB or is invalid"]
            )
        }

        do {
            let sha256 = try await getFileSHA256(for: scanFileURL)
            FilePreparation.cleanupPreparedFile(at: batchFile.preparedFileURL)
            batchFile.preparedFileURL = scanFileURL
            batchFile.fileName = fileName
            batchFile.fileSize = fileSize
            batchFile.sha256 = sha256
        } catch {
            FilePreparation.cleanupPreparedFile(at: scanFileURL)
            throw NSError(
                domain: "VirusTotal.FileBatchViewModel",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Failed to calculate SHA256"]
            )
        }
    }

    private func uploadFile(_ batchFile: BatchFile, cancellationToken: FileAnalysisCancellationToken) async throws -> Bool {
        var apiEndpoint = chooseUploadEndpoint(for: batchFile)

        // Get large file endpoint if needed
        if ScanPolicy.requiresLargeUploadEndpoint(fileSize: batchFile.fileSize) {
            let endpointResult = try await FileAnalysis.shared.getLargeFileEndpoint(cancellationToken: cancellationToken)
            try Task.checkCancellation()
            guard endpointResult.getEndpointSuccess == true,
                  let largeEndpoint = endpointResult.largeFileEndpoint else {
                log.error("Failed to get large file endpoint")
                return false
            }
            apiEndpoint = largeEndpoint
        }

        let progressHandler: @Sendable (Double) -> Void = { [weak batchFile] progress in
            Task { @MainActor in
                guard batchFile?.status == .uploading else { return }
                batchFile?.uploadProgress = progress
            }
        }

        let uploadResult = try await FileAnalysis.shared.uploadFile(
            fileURL: batchFile.preparedFileURL,
            apiEndPoint: apiEndpoint,
            cancellationToken: cancellationToken,
            progressHandler: progressHandler
        )

        return uploadResult.uploadSuccess == true
    }

    private func getAnalysisResults(_ batchFile: BatchFile, cancellationToken: FileAnalysisCancellationToken) async {
        var retryCount = 0
        let maxRetries = ScanPolicy.maxPollingAttempts // 28 * 10 seconds = ~5 minutes

        while retryCount < maxRetries {
            guard !Task.isCancelled else { return }

            do {
                let reportResult = try await FileAnalysis.shared.getFileReport(
                    sha256: batchFile.sha256,
                    cancellationToken: cancellationToken
                )
                try Task.checkCancellation()

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

            } catch is CancellationError {
                return
            } catch {
                batchFile.status = .failed
                await NotificationManager.pushNotification(title: String(localized: "notification.analysis.fail.title"))
                batchFile.errorMessage = error.displayMessageWithCode
                log.error(batchFile.errorMessage ?? "Unknown Error")
                updateCompletedCount()
                return
            }
        }

        guard !Task.isCancelled else { return }
        batchFile.status = .failed
        await NotificationManager.pushNotification(title: String(localized: "notification.analysis.fail.title"))
        batchFile.errorMessage = String(localized: "error.analysis.timeout")
        log.error(batchFile.errorMessage ?? "Unknown Error")
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
        ScanPolicy.uploadEndpoint(forFileSize: batchFile.fileSize)
    }

    private func isValidResponse(_ stats: FileAnalysisStats) -> Bool {
        ScanPolicy.isValidAnalysisStats(stats)
    }

    private func generateThumbnail(for batchFile: BatchFile) async {
        let size = CGSize(width: 32, height: 32)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let request = QLThumbnailGenerator.Request(
            fileAt: batchFile.preparedFileURL,
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

    private func getFileSHA256(for fileURL: URL) async throws -> String {
        try await FileHasher.sha256Async(for: fileURL)
    }

    private func releaseSecurityScopedAccess(for url: URL) {
        guard securityScopedFileURLs.remove(url) != nil else { return }
        url.stopAccessingSecurityScopedResource()
    }

    private func releaseAllSecurityScopedAccess() {
        for url in securityScopedFileURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedFileURLs.removeAll()
    }
}

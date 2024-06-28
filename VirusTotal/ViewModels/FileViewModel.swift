//
//  FileViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import SwiftUI
import CryptoKit
import QuickLookThumbnailing

@MainActor
final class FileViewModel: ObservableObject {
    static let shared = FileViewModel()

    @Published var statusMonitor: AnalysisStatus?
    @Published var errorMessage: String?
    @Published var lastAnalysisStats: FileAnalysisStats?
    @Published var typeDescription: String?
    @Published var lastAnalysisDate: String?
    @Published var reputation: Int?
    @Published var uniqueSources: Int?

    @Published var fileSize: Int64?
    @Published var fileName: String?
    @Published var thumbnailImage: NSImage?

    // Not stable due to URLSession's behaviors
    // https://github.com/Alamofire/Alamofire/issues/3813
    @Published var uploadProgress: Double = 0.0

    var inputSHA256: String = ""

    /// Handle the File Import modifier, run setupFileInfo and getFileReport
    func handleFileImport(_ url: URL) async {
        _ = url.startAccessingSecurityScopedResource()
        await setupFileInfo(fileURL: url)
        await getFileReport()
    }

    /// Given a fileURL, setup fileSize, fileName, thumbnailImage, and fileSHA256
    func setupFileInfo(fileURL: URL) async {
        self.cancellationRequested = false
        self.fileURL = fileURL
        let fileSize = getFileSize(for: fileURL)
        guard fileSize < 681_574_400 else {
            log.error("Filesize \(fileSize) exceeded 650 MB.")
            self.errorMessage = "Local Error: VirusTotal only accepts files up to 650 MB"
            self.statusMonitor = .fail
            return
        }
        self.fileSize = fileSize
        self.fileName = getFileName(for: fileURL)
        await getThumbnailImage(for: fileURL)
        if let fileSHA256 = self.getFileSHA256(for: fileURL) {
            self.inputSHA256 = fileSHA256
        }
    }

    func getNewFileReport() async {
        guard !self.cancellationRequested else { return }
        self.numberOfRetries = 0 // Reset retry count when a new request is made
        await getFileReport()
    }

    /// Given a file sha256, get the report of the file
    func getFileReport() async {
        guard !self.cancellationRequested else { return }
        do {
            let result = try await FileAnalysis.shared.getFileReport(sha256: inputSHA256)
            self.statusMonitor = result.statusMonitor
            self.errorMessage = result.errorMessage
            self.lastAnalysisStats = result.lastAnalysisStats
            self.typeDescription = result.typeDescription
            self.lastAnalysisDate = result.lastAnalysisDate
            self.reputation = result.reputation
            self.uniqueSources = result.uniqueSources

            if result.getReportSuccess == true {
                if self.isValidResponse(responses: result.lastAnalysisStats!) {
                    self.statusMonitor = .success
                } else {
                    await self.retryFileReport(retryCount: self.numberOfRetries)
                }
            } else {
                self.errorMessage = result.errorMessage
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.statusMonitor = .fail
        }
    }

    /// Upload file
    func uploadFile() async throws -> Bool {
        guard !self.cancellationRequested else { return false }
        self.statusMonitor = .uploading

        let updateProgress: @Sendable (Double) -> Void = { [weak self] progress in
            Task { @MainActor [weak self] in
                self?.uploadProgress = progress
            }
        }

        do {
            let uploadResult = try await FileAnalysis.shared.uploadFile(
                fileURL: self.fileURL ?? defaultFileURL,
                apiEndPoint: chooseUploadEndpoint(),
                progressHandler: updateProgress
            )
            if uploadResult.uploadSuccess == true {
                self.statusMonitor = .analyzing
                self.uploadSuccess = true
                return true
            } else {
                self.errorMessage = uploadResult.errorMessage
                self.statusMonitor = uploadResult.statusMonitor
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.statusMonitor = .fail
            return false
        }
    }

    /// Fetch the large file upload endpoint
    func fetchLargeFileEndpoint() async throws -> Bool {
        guard !self.cancellationRequested else { return false }
        do {
            let endpointResult = try await FileAnalysis.shared.getLargeFileEndpoint()
            if endpointResult.getEndpointSuccess == true {
                self.largeFileEndpoint = endpointResult.largeFileEndpoint
                return true
            } else {
                self.errorMessage = endpointResult.errorMessage
                self.statusMonitor = endpointResult.statusMonitor
                return false
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.statusMonitor = .fail
            return false
        }
    }

    /// Start file upload based on file size
    func startFileUpload() async {
        guard !self.cancellationRequested else { return }
        guard let fileSize = self.fileSize else {
            log.error("No File Size \(String(describing: fileSize))")
            self.errorMessage = noFileSizeError
            self.statusMonitor = .fail
            return
        }

        do {
            switch fileSize {
            case ..<33_554_432:
                if try await uploadFile() {
                    try await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
                    await getNewFileReport()
                }
            case 33_554_432...681_574_400:
                if try await fetchLargeFileEndpoint() {
                    if try await uploadFile() {
                        try await Task.sleep(nanoseconds: 20_000_000_000) // 20 seconds
                        await getNewFileReport()
                    }
                } else {
                    log.error("Failed to fetch large file upload endpoint.")
                    self.errorMessage = "Failed to fetch large file upload endpoint."
                    self.statusMonitor = .fail
                }
            default:
                self.errorMessage = "Unexpected file size."
                self.statusMonitor = .fail
            }
        } catch {
            self.errorMessage = error.localizedDescription
            self.statusMonitor = .fail
        }
    }

    // Request to re-analyze a file
    func requestReanalyze() async {
        guard !self.cancellationRequested else { return }
        do {
            try await FileAnalysis.shared.reanalyzeFile(sha256: inputSHA256)
            await getNewFileReport()
            self.errorMessage = nil
        } catch {
            log.error(error.localizedDescription)
            self.statusMonitor = .fail
            self.errorMessage = error.localizedDescription
        }
    }

    /// Cancel on-going AF request and stop model from running
    func cancelOngoingRequest() {
        Task {
            await FileAnalysis.shared.cancelAFRequest()
            cancellationRequested = true
        }
    }

    // MARK: Private

    private var fileURL: URL?
    private var cancellationRequested = false // Flag to track cancellation of code
    private var largeFileEndpoint: String?
    private var uploadSuccess: Bool?
    private var numberOfRetries = 0
    private let defaultFileURL = URL(string: "file://")!
    private let noFileSizeError: String = "Local Error: Can't retrieve file size"
    private let defaultUploadURL: String = "https://www.virustotal.com/api/v3/files"

    /// Given a fileURL, return the file size in bytes
    private func getFileSize(for fileURL: URL) -> Int64 {
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            return fileAttributes[.size] as? Int64 ?? 0
        } catch {
            log.error("Error getting file size: \(error)")
            return 0
        }
    }

    /// Given a fileURL, return the file name
    private func getFileName(for fileURL: URL) -> String {
        return fileURL.lastPathComponent
    }

    /// Given a fileURL, return the sha256 value of the given file
    private func getFileSHA256(for fileURL: URL) -> String? {
        guard let fileData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        let hash = SHA256.hash(data: fileData)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Given a fileURL, generate a thumbnail icon and pass it to the viewModel
    private func getThumbnailImage(for fileURL: URL) async {
        let selectedFileURL: URL = fileURL
        let size = CGSize(width: 50, height: 50)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let request = QLThumbnailGenerator.Request(fileAt: selectedFileURL,
                                                   size: size,
                                                   scale: scale,
                                                   representationTypes: .icon)

        do {
            let thumbnail = try await withCheckedThrowingContinuation { continuation in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { thumbnail, error in
                    if let thumbnail = thumbnail {
                        continuation.resume(returning: thumbnail)
                    } else {
                        continuation.resume(throwing: error ?? VTError.local("Unknown error generating Thumbnail."))
                    }
                }
            }
            self.thumbnailImage = thumbnail.thumbnailImage
        } catch {
            log.error("Thumbnail Error: \(error)")
        }
    }

    /// Choose the upload endpoint for uploadFile() func
    private func chooseUploadEndpoint() -> String {
        let fileSize = self.fileSize ?? 0
        if fileSize <= 33_554_432 {
            return defaultUploadURL
        } else if fileSize > 33_554_432 && fileSize <= 681_574_400 {
            return largeFileEndpoint ?? defaultUploadURL
        } else {
            return "" // Files >650MB are not supported
        }
    }

    /// Given a FileAnalysisStats, return true if the sum of the flags is not 0, false otherwise
    private func isValidResponse(responses: FileAnalysisStats) -> Bool {
        return responses.allFlags.sum { $0 } != 0
    }

    /// Retry getting file report to wait for the server processing time when new file is scanned
    /// getFileReport() will be called every 10 seconds up to 28 times (300 seconds)
    private func retryFileReport(retryCount: Int) async {
        guard !self.cancellationRequested else { return }
        guard retryCount < 28 else {
            log.error("Request Timeout. \(self.errorMessage ?? "")")
            self.errorMessage = "Request timeout." + (self.errorMessage ?? "")
            self.statusMonitor = .fail
            return
        }

        do {
            try await Task.sleep(for: .seconds(10))
            self.numberOfRetries += 1
            await getFileReport()

            if self.statusMonitor != .success {
                return await retryFileReport(retryCount: self.numberOfRetries)
            }
        } catch {
            self.errorMessage = "Error during retry: \(error.localizedDescription)"
            self.statusMonitor = .fail
        }
    }
}

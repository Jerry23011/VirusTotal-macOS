//
//  FileViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import SwiftUI
import QuickLookThumbnailing

@MainActor
@Observable
final class FileViewModel {
    static let shared = FileViewModel()

    var statusMonitor: AnalysisStatus?
    var errorMessage: String?
    var lastAnalysisStats: FileAnalysisStats?
    var typeDescription: String?
    var lastAnalysisDate: String?
    var reputation: Int?
    var uniqueSources: Int?

    var fileSize: Int64?
    var fileName: String?
    var thumbnailImage: NSImage?

    // Not stable due to URLSession's behaviors
    // https://github.com/Alamofire/Alamofire/issues/3813
    var uploadProgress: Double = 0.0

    var inputSHA256: String = ""

    /// Start importing a file, replacing any import still in progress.
    /// The task is kept so going back can stop archiving, hashing and polling.
    @discardableResult
    func startFileImport(_ url: URL) -> Task<Void, Never> {
        importTask?.cancel()
        let task = Task {
            await handleFileImport(url)
        }
        importTask = task
        return task
    }

    /// Handle the File Import modifier, run setupFileInfo and getFileReport
    func handleFileImport(_ url: URL) async {
        await setupFileInfo(fileURL: url)
        guard !Task.isCancelled else { return }
        await getFileReport()
    }

    /// Given a fileURL, setup fileSize, fileName, thumbnailImage, and fileSHA256
    func setupFileInfo(fileURL: URL) async {
        cancelCurrentRequest()
        cleanupPreparedFile()
        resetScanState()
        activateSecurityScopedAccess(for: fileURL)
        let token = FileAnalysisCancellationToken()
        self.currentCancellationToken = token
        self.statusMonitor = .loading

        let scanFileURL: URL
        do {
            scanFileURL = try await FilePreparation.scanFileURL(for: fileURL)
        } catch {
            guard !isStale(token) else { return }
            releaseSecurityScopedAccess()
            log.error("Error preparing file for scan: \(error)")
            self.errorMessage = "Local Error: \(error.displayMessageWithCode)"
            self.statusMonitor = .fail
            return
        }

        // A newer scan or a cancellation already released this scan's
        // resources, so only the archive made here is left to remove.
        guard !isStale(token) else {
            FilePreparation.cleanupPreparedFile(at: scanFileURL)
            return
        }

        self.fileURL = scanFileURL
        let fileSize = getFileSize(for: scanFileURL)
        guard ScanPolicy.isSupportedFileSize(fileSize) else {
            log.error("Filesize \(fileSize) exceeded 650 MB.")
            self.errorMessage = "Local Error: VirusTotal only accepts files up to 650 MB"
            self.statusMonitor = .fail
            cleanupPreparedFile()
            return
        }
        self.fileSize = fileSize
        self.fileName = getFileName(for: scanFileURL)
        await getThumbnailImage(for: scanFileURL, token: token)
        guard !isStale(token) else { return }
        await setupFileSHA256(for: scanFileURL, token: token)
    }

    private func setupFileSHA256(for scanFileURL: URL, token: FileAnalysisCancellationToken) async {
        do {
            let sha256 = try await getFileSHA256(for: scanFileURL)
            guard !isStale(token) else { return }
            self.inputSHA256 = sha256
        } catch {
            guard !isStale(token) else { return }
            cleanupPreparedFile()
            guard !(error is CancellationError) else { return }
            log.error("Error calculating SHA256 for \(scanFileURL): \(error)")
            self.errorMessage = "Local Error: \(error.displayMessageWithCode)"
            self.statusMonitor = .fail
        }
    }

    func getNewFileReport() async {
        guard !isStale(currentCancellationToken) else { return }
        self.numberOfRetries = 0 // Reset retry count when a new request is made
        await getFileReport()
    }

    /// Given a file sha256, get the report of the file
    func getFileReport() async {
        let token = currentCancellationToken
        guard !isStale(token) else { return }
        guard self.statusMonitor != .fail else { return }
        do {
            let result = try await FileAnalysis.shared.getFileReport(
                sha256: inputSHA256,
                cancellationToken: token
            )
            guard !isStale(token) else { return }

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
                    await NotificationManager.pushNotification(title: String(localized: "notification.analysis.complete.title"))
                    self.storeScanEntry()
                    cleanupPreparedFile()
                } else {
                    await self.retryFileReport(retryCount: self.numberOfRetries)
                }
            } else if self.statusMonitor == .fail {
                self.errorMessage = result.errorMessage
                cleanupPreparedFile()
            } else if self.uploadSuccess == true {
                // The file was uploaded, so a 404 here means VirusTotal is
                // still building the report, not that the file is unknown.
                // Without this the scan stopped silently and never resumed.
                self.statusMonitor = .analyzing
                await self.retryFileReport(retryCount: self.numberOfRetries)
            } else {
                self.errorMessage = result.errorMessage
            }
        } catch is CancellationError {
            guard !isStale(token) else { return }
            cleanupPreparedFile()
        } catch {
            guard !isStale(token) else { return }
            self.errorMessage = error.displayMessageWithCode
            await NotificationManager.pushNotification(title: String(localized: "notification.analysis.fail.title"))
            self.statusMonitor = .fail
            cleanupPreparedFile()
        }
    }

    /// Upload file
    func uploadFile() async throws -> Bool {
        let token = currentCancellationToken
        guard !isStale(token) else { return false }
        self.statusMonitor = .uploading

        let updateProgress: @Sendable (Double) -> Void = { [weak self] progress in
            Task { @MainActor [weak self] in
                guard let self, !self.isStale(token) else { return }
                self.uploadProgress = progress
            }
        }

        do {
            let uploadResult = try await FileAnalysis.shared.uploadFile(
                fileURL: self.fileURL ?? defaultFileURL,
                apiEndPoint: chooseUploadEndpoint(),
                cancellationToken: token,
                progressHandler: updateProgress
            )
            guard !isStale(token) else { return false }

            if uploadResult.uploadSuccess == true {
                self.statusMonitor = .analyzing
                self.uploadSuccess = true
                self.currentAnalysisId = uploadResult.analysisId
                return true
            } else {
                self.errorMessage = uploadResult.errorMessage
                self.statusMonitor = uploadResult.statusMonitor
                return false
            }
        } catch is CancellationError {
            return false
        } catch {
            guard !isStale(token) else { return false }
            self.errorMessage = error.displayMessageWithCode
            await NotificationManager.pushNotification(title: String(localized: "notification.upload.fail.title"))
            self.statusMonitor = .fail
            return false
        }
    }

    /// Fetch the large file upload endpoint
    func fetchLargeFileEndpoint() async throws -> Bool {
        let token = currentCancellationToken
        guard !isStale(token) else { return false }
        do {
            let endpointResult = try await FileAnalysis.shared.getLargeFileEndpoint(cancellationToken: token)
            guard !isStale(token) else { return false }

            if endpointResult.getEndpointSuccess == true {
                self.largeFileEndpoint = endpointResult.largeFileEndpoint
                return true
            } else {
                self.errorMessage = endpointResult.errorMessage
                self.statusMonitor = endpointResult.statusMonitor
                return false
            }
        } catch is CancellationError {
            return false
        } catch {
            guard !isStale(token) else { return false }
            self.errorMessage = error.displayMessageWithCode
            self.statusMonitor = .fail
            return false
        }
    }

    /// Start file upload based on file size
    func startFileUpload() async {
        let token = currentCancellationToken
        guard !isStale(token) else { return }
        guard let fileSize = self.fileSize else {
            log.error("No File Size \(String(describing: fileSize))")
            self.errorMessage = noFileSizeError
            self.statusMonitor = .fail
            return
        }

        defer {
            if !isStale(token) {
                cleanupPreparedFile()
            }
        }

        do {
            switch fileSize {
            case ...ScanPolicy.largeUploadThreshold:
                try await uploadCurrentFileAndFetchReport()
            case (ScanPolicy.largeUploadThreshold + 1)...ScanPolicy.maxUploadSize:
                if try await fetchLargeFileEndpoint() {
                    try await uploadCurrentFileAndFetchReport()
                } else {
                    handleLargeFileEndpointFailure()
                }
            default:
                self.errorMessage = "Unexpected file size."
                self.statusMonitor = .fail
            }
        } catch is CancellationError {
            return
        } catch {
            guard !isStale(token) else { return }
            self.errorMessage = error.displayMessageWithCode
            self.statusMonitor = .fail
        }
    }

    private func uploadCurrentFileAndFetchReport() async throws {
        let token = currentCancellationToken
        guard try await uploadFile(), !isStale(token) else { return }
        try await waitForQueuedAnalysis()
        guard !isStale(token) else { return }
        await getNewFileReport()
    }

    /// Wait on `/analyses/{id}` until VirusTotal says the analysis is done.
    /// The file report is only published once the backend finishes, so asking
    /// for it after a fixed delay raced the queue and left new files hanging.
    private func waitForQueuedAnalysis() async throws {
        let token = currentCancellationToken
        guard !isStale(token) else { throw CancellationError() }
        if let analysisID = currentAnalysisId {
            try await FileAnalysis.shared.waitForAnalysis(analysisId: analysisID, cancellationToken: token)
        }
        guard !isStale(token) else { throw CancellationError() }
    }

    private func handleLargeFileEndpointFailure() {
        guard !isStale(currentCancellationToken) else { return }
        log.error("Failed to fetch large file upload endpoint.")
        self.errorMessage = "Failed to fetch large file upload endpoint."
        self.statusMonitor = .fail
    }

    // Request to re-analyze a file
    func requestReanalyze() async {
        let token = currentCancellationToken
        guard !isStale(token) else { return }
        do {
            try await FileAnalysis.shared.reanalyzeFile(
                sha256: inputSHA256,
                cancellationToken: token
            )
            guard !isStale(token) else { return }
            await getNewFileReport()
            self.errorMessage = nil
        } catch is CancellationError {
            return
        } catch {
            guard !isStale(token) else { return }
            log.error(error.localizedDescription)
            self.statusMonitor = .fail
            self.errorMessage = error.displayMessageWithCode
        }
    }

    /// Cancel on-going requests and stop model from running.
    func cancelOngoingRequest() {
        importTask?.cancel()
        importTask = nil
        cancelCurrentRequest()
        cleanupPreparedFile()
    }

    // MARK: Private

    deinit {
        MainActor.assumeIsolated {
            securityScopedFileURL?.stopAccessingSecurityScopedResource()
        }
    }

    private var fileURL: URL?
    private var securityScopedFileURL: URL?
    /// Identifies the current scan. Replaced by every new scan and cleared on
    /// cancel, so work that finishes late can tell it no longer owns the model.
    private var currentCancellationToken: FileAnalysisCancellationToken?
    private var importTask: Task<Void, Never>?
    private var largeFileEndpoint: String?
    private var uploadSuccess: Bool?
    private var numberOfRetries = 0
    private var currentAnalysisId: String?
    private let defaultFileURL = URL(string: "file://")!
    private let noFileSizeError: String = "Local Error: Can't retrieve file size"
    private let defaultUploadURL: String = ScanPolicy.defaultUploadEndpoint

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
    private func getFileSHA256(for fileURL: URL) async throws -> String {
        try await FileHasher.sha256Async(for: fileURL)
    }

    /// Given a fileURL, generate a thumbnail icon and pass it to the viewModel
    private func getThumbnailImage(for fileURL: URL, token: FileAnalysisCancellationToken) async {
        let selectedFileURL: URL = fileURL
        let size = CGSize(width: 50, height: 50)
        let scale = NSScreen.main?.backingScaleFactor ?? 1.0
        let request = QLThumbnailGenerator.Request(fileAt: selectedFileURL,
                                                   size: size,
                                                   scale: scale,
                                                   representationTypes: .icon)

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            guard !isStale(token) else { return }
            self.thumbnailImage = thumbnail.nsImage
        } catch {
            log.warning("Thumbnail Error: \(error)")
        }
    }

    /// Choose the upload endpoint for uploadFile() func
    private func chooseUploadEndpoint() -> String {
        let fileSize = self.fileSize ?? 0
        return ScanPolicy.uploadEndpoint(forFileSize: fileSize, largeFileEndpoint: largeFileEndpoint)
    }

    private func cleanupPreparedFile() {
        if let fileURL {
            FilePreparation.cleanupPreparedFile(at: fileURL)
            self.fileURL = nil
        }
        releaseSecurityScopedAccess()
    }

    private func activateSecurityScopedAccess(for url: URL) {
        releaseSecurityScopedAccess()
        if url.startAccessingSecurityScopedResource() {
            securityScopedFileURL = url
        }
    }

    private func releaseSecurityScopedAccess() {
        securityScopedFileURL?.stopAccessingSecurityScopedResource()
        securityScopedFileURL = nil
    }

    /// True once the scan that owns `token` was cancelled or replaced.
    private func isStale(_ token: FileAnalysisCancellationToken?) -> Bool {
        token == nil || token !== currentCancellationToken
    }

    /// Clear what the previous file left behind, so a new unknown file is
    /// uploaded instead of being treated as already uploaded.
    private func resetScanState() {
        self.uploadSuccess = nil
        self.currentAnalysisId = nil
        self.largeFileEndpoint = nil
        self.numberOfRetries = 0
        self.uploadProgress = 0.0
        self.inputSHA256 = ""
        self.thumbnailImage = nil
        self.lastAnalysisStats = nil
        self.typeDescription = nil
        self.lastAnalysisDate = nil
        self.reputation = nil
        self.uniqueSources = nil
        self.errorMessage = nil
    }

    private func cancelCurrentRequest() {
        currentCancellationToken?.cancelAll()
        currentCancellationToken = nil
    }

    /// Given a FileAnalysisStats, return true if the sum of the flags is not 0, false otherwise
    private func isValidResponse(responses: FileAnalysisStats) -> Bool {
        ScanPolicy.isValidAnalysisStats(responses)
    }

    /// Retry getting file report to wait for the server processing time when new file is scanned
    /// getFileReport() will be called every 10 seconds up to 28 times (300 seconds)
    private func retryFileReport(retryCount: Int) async {
        let token = currentCancellationToken
        guard !isStale(token) else { return }
        guard retryCount < 28 else {
            log.error("Request Timeout. \(self.errorMessage ?? "")")
            self.errorMessage = "Request timeout." + (self.errorMessage ?? "")
            self.statusMonitor = .fail
            cleanupPreparedFile()
            return
        }

        do {
            try await Task.sleep(for: .seconds(10))
            guard !isStale(token) else { return }
            self.numberOfRetries += 1
            await getFileReport()

            switch self.statusMonitor {
            case .success, .fail:
                return
            default:
                return await retryFileReport(retryCount: self.numberOfRetries)
            }
        } catch is CancellationError {
            return
        } catch {
            guard !isStale(token) else { return }
            self.errorMessage = "Error during retry: \(error.displayMessageWithCode)"
            self.statusMonitor = .fail
            cleanupPreparedFile()
        }
    }
}

//
//  DownloadsMonitorViewModel.swift
//  VirusTotal
//

import Defaults
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class DownloadScanItem: Identifiable {
    let id = UUID()
    let originalFileURL: URL
    let preparedFileURL: URL
    let fileName: String
    let fileSize: Int64
    let sha256: String

    var status: DownloadScanStatus = .queued
    var uploadProgress: Double = 0
    var analysisStats: FileAnalysisStats?
    var errorMessage: String?

    init(originalFileURL: URL, preparedFileURL: URL, fileSize: Int64, sha256: String) {
        self.originalFileURL = originalFileURL
        self.preparedFileURL = preparedFileURL
        self.fileName = originalFileURL.lastPathComponent
        self.fileSize = fileSize
        self.sha256 = sha256
    }
}

enum DownloadScanStatus {
    case queued
    case preparing
    case uploading
    case analyzing
    case success
    case failed
}

@MainActor
@Observable
final class DownloadsMonitorViewModel {
    static let shared = DownloadsMonitorViewModel()

    var scanItems: [DownloadScanItem] = []
    var isEnabled: Bool = Defaults[.autoScanDownloadsEnabled]
    var folderURL: URL = DownloadsMonitorViewModel.savedFolderURL
    var statusMessage: String = NSLocalizedString("downloadsmonitor.status.off", comment: "")
    var selectedFilePath: String?
    var selectedFileCategories: Set<DownloadMonitorFileCategory> = Set(Defaults[.downloadMonitorFileCategories])

    var hasSavedFolderAccess: Bool {
        !Defaults[.autoScanDownloadsFolderBookmark].isEmpty
    }

    var hasActiveScanItems: Bool {
        scanItems.contains { isActiveStatus($0.status) }
    }

    private var monitorTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var scanTaskID: UUID?
    private var scanExistingTask: Task<Void, Never>?
    private var scanExistingTaskID: UUID?
    private var scanCancellationToken: FileAnalysisCancellationToken?
    private var knownFileFingerprints: [String: String] = [:]
    private var queuedFileFingerprints: Set<String> = []
    private var queuedFileHashes: Set<String> = []
    private var securityScopedFolderURL: URL?
    private let defaultUploadURL = ScanPolicy.defaultUploadEndpoint

    private init() {}

    func startIfNeeded() {
        let shouldEnable = Defaults[.autoScanDownloadsEnabled]
            && Defaults[.didConfirmAutoScanUploads]
            && hasSavedFolderAccess

        folderURL = Self.savedFolderURL
        isEnabled = shouldEnable
        Defaults[.autoScanDownloadsEnabled] = shouldEnable

        guard shouldEnable else {
            if monitorTask != nil {
                stopMonitoring()
            } else {
                statusMessage = localizedString("downloadsmonitor.status.off")
            }
            return
        }

        guard monitorTask == nil else { return }
        startMonitoring()
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        guard !enabled || hasSavedFolderAccess else {
            isEnabled = false
            Defaults[.autoScanDownloadsEnabled] = false
            statusMessage = localizedString("downloadsmonitor.status.choose_folder")
            return
        }

        Defaults[.autoScanDownloadsEnabled] = enabled
        isEnabled = enabled

        if enabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    func setFolderURL(_ url: URL) {
        cancelScanExistingTask()
        saveSecurityScopedBookmark(for: url)
        Defaults[.autoScanDownloadsFolderPath] = url.path
        folderURL = url
        if !isEnabled {
            securityScopedFolderURL?.stopAccessingSecurityScopedResource()
            securityScopedFolderURL = nil
        }
        knownFileFingerprints.removeAll()
        queuedFileFingerprints.removeAll()
        queuedFileHashes.removeAll()

        if isEnabled {
            startMonitoring()
        }
    }

    func scanExistingFiles() {
        guard scanExistingTask == nil else { return }

        let taskID = UUID()
        scanExistingTaskID = taskID
        scanExistingTask = Task { [weak self] in
            guard let self else { return }
            await self.scanFolder(includeKnownFiles: true)
            let wasCancelled = Task.isCancelled

            await MainActor.run {
                guard self.scanExistingTaskID == taskID else { return }
                self.scanExistingTask = nil
                self.scanExistingTaskID = nil

                if !wasCancelled {
                    self.startScanQueueIfNeeded()
                }
            }
        }
    }

    func setFileCategory(_ category: DownloadMonitorFileCategory, isEnabled: Bool) {
        if isEnabled {
            selectedFileCategories.insert(category)
        } else {
            selectedFileCategories.remove(category)
        }

        Defaults[.downloadMonitorFileCategories] = Array(selectedFileCategories)
        if isEnabled {
            snapshotCurrentFiles()
        }
    }

    func handleNotificationSelection(filePath: String?) {
        guard let filePath else { return }
        selectedFilePath = filePath

        if let index = scanItems.firstIndex(where: { $0.originalFileURL.path == filePath }) {
            let item = scanItems.remove(at: index)
            scanItems.insert(item, at: 0)
        }
    }

    func eligibleFileCount() -> Int {
        do {
            return try withFolderAccess {
                try eligibleFileURLs().count
            }
        } catch {
            statusMessage = cannotReadFolderMessage(error)
            log.error("Downloads monitor failed to count folder files: \(error)")
            return 0
        }
    }

    func clearResults() {
        guard !hasActiveScanItems else { return }
        scanItems.forEach { FilePreparation.cleanupPreparedFile(at: $0.preparedFileURL) }
        scanItems.removeAll()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        stopMonitoring()
        activateFolderAccess(for: folderURL)
        statusMessage = monitoringMessage(for: folderURL)

        Task {
            await NotificationManager.requestAuthorization()
        }

        monitorTask = Task { [weak self] in
            guard let self else { return }
            self.snapshotCurrentFiles()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled else { break }
                await self.scanFolder(includeKnownFiles: false)
                self.startScanQueueIfNeeded()
            }
        }
    }

    private func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        cancelScanExistingTask()
        scanTask?.cancel()
        scanTask = nil
        scanTaskID = nil
        scanCancellationToken?.cancelAll()
        scanCancellationToken = nil
        cancelQueuedScanItems()
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        securityScopedFolderURL = nil
        statusMessage = localizedString("downloadsmonitor.status.off")
    }

    private func cancelScanExistingTask() {
        scanExistingTask?.cancel()
        scanExistingTask = nil
        scanExistingTaskID = nil
    }

    private func cancelQueuedScanItems() {
        for item in scanItems where isActiveStatus(item.status) {
            FilePreparation.cleanupPreparedFile(at: item.preparedFileURL)
            item.status = .failed
            item.uploadProgress = 0
            item.errorMessage = localizedString("common.cancelled")
        }
        queuedFileFingerprints.removeAll()
        queuedFileHashes.removeAll()
    }

    private func snapshotCurrentFiles() {
        do {
            knownFileFingerprints = Dictionary(
                uniqueKeysWithValues: try eligibleFileURLs().map { ($0.path, fileFingerprint(for: $0)) }
            )
            if isEnabled {
                statusMessage = monitoringMessage(for: folderURL)
            }
        } catch {
            statusMessage = cannotReadFolderMessage(error)
            log.error("Downloads monitor failed to snapshot folder: \(error)")
        }
    }

    private func scanFolder(includeKnownFiles: Bool) async {
        do {
            try await withFolderAccess {
                let urls = try eligibleFileURLs()

                for url in urls {
                    guard !Task.isCancelled else { return }
                    let fingerprint = fileFingerprint(for: url)

                    if includeKnownFiles {
                        knownFileFingerprints[url.path] = fingerprint
                        _ = await queueFileIfNeeded(url)
                    } else {
                        guard knownFileFingerprints[url.path] != fingerprint else { continue }

                        if await queueFileIfNeeded(url) {
                            knownFileFingerprints[url.path] = fingerprint
                        }
                    }
                }
            }
        } catch {
            statusMessage = cannotReadFolderMessage(error)
            log.error("Downloads monitor failed to read folder: \(error)")
        }
    }

    private func queueFileIfNeeded(_ url: URL) async -> Bool {
        guard let stableURL = await waitForStableFile(at: url) else { return false }
        let fingerprint = fileFingerprint(for: stableURL)
        guard !queuedFileFingerprints.contains(fingerprint) else { return true }

        let preparedURL: URL
        do {
            preparedURL = try await FilePreparation.scanFileURL(for: stableURL)
        } catch {
            appendFailedItem(url: stableURL, message: localErrorMessage(error))
            return true
        }

        let fileSize = fileSize(for: preparedURL)
        guard ScanPolicy.isSupportedFileSize(fileSize) else {
            appendFailedItem(originalURL: stableURL, preparedURL: preparedURL, message: localizedString("downloadsmonitor.error.file_size"))
            FilePreparation.cleanupPreparedFile(at: preparedURL)
            return true
        }

        do {
            let sha256 = try await sha256(for: preparedURL)
            guard !queuedFileHashes.contains(sha256) else {
                FilePreparation.cleanupPreparedFile(at: preparedURL)
                return true
            }

            queuedFileFingerprints.insert(fingerprint)
            queuedFileHashes.insert(sha256)
            scanItems.insert(
                DownloadScanItem(
                    originalFileURL: stableURL,
                    preparedFileURL: preparedURL,
                    fileSize: fileSize,
                    sha256: sha256
                ),
                at: 0
            )
            statusMessage = queuedMessage(for: stableURL)
            return true
        } catch is CancellationError {
            FilePreparation.cleanupPreparedFile(at: preparedURL)
            return false
        } catch {
            appendFailedItem(originalURL: stableURL, preparedURL: preparedURL, message: localizedString("downloadsmonitor.error.sha256"))
            FilePreparation.cleanupPreparedFile(at: preparedURL)
            return true
        }
    }

    private func startScanQueueIfNeeded() {
        guard scanTask == nil else { return }

        let taskID = UUID()
        scanTaskID = taskID
        scanTask = Task { [weak self] in
            guard let self else { return }
            await self.processQueuedItems()
            await MainActor.run {
                guard self.scanTaskID == taskID else { return }
                self.scanTask = nil
                self.scanTaskID = nil
                self.scanCancellationToken = nil
            }
        }
    }

    // MARK: - Scanning

    private func processQueuedItems() async {
        while let item = scanItems.reversed().first(where: { $0.status == .queued }) {
            guard !Task.isCancelled else { return }
            await process(item)
        }
    }

    private func process(_ item: DownloadScanItem) async {
        let cancellationToken = FileAnalysisCancellationToken()
        scanCancellationToken = cancellationToken
        defer {
            if scanCancellationToken === cancellationToken {
                scanCancellationToken = nil
            }
            FilePreparation.cleanupPreparedFile(at: item.preparedFileURL)
        }

        item.status = .preparing

        do {
            let reportResult = try await FileAnalysis.shared.getFileReport(
                sha256: item.sha256,
                cancellationToken: cancellationToken
            )
            try Task.checkCancellation()

            if reportResult.getReportSuccess == true,
               let stats = reportResult.lastAnalysisStats,
               isValidResponse(stats) {
                complete(item, with: reportResult)
                return
            }

            guard reportResult.statusMonitor != .fail else {
                fail(item, message: reportResult.errorMessage ?? localizedString("downloadsmonitor.error.report"))
                return
            }

            item.status = .uploading
            notifyUploadStarted(for: item)
            if try await upload(item, cancellationToken: cancellationToken) {
                try Task.checkCancellation()
                item.status = .analyzing
                try await Task.sleep(for: .seconds(20))
                await waitForAnalysis(item, cancellationToken: cancellationToken)
            } else {
                fail(item, message: localizedString("downloadsmonitor.error.upload_failed"))
            }
        } catch is CancellationError {
            if scanCancellationToken === cancellationToken,
               scanItems.contains(where: { $0.id == item.id }) {
                item.status = .queued
                item.uploadProgress = 0
            }
        } catch {
            fail(item, message: error.displayMessageWithCode)
        }
    }

    private func upload(_ item: DownloadScanItem, cancellationToken: FileAnalysisCancellationToken) async throws -> Bool {
        var endpoint = defaultUploadURL
        if ScanPolicy.requiresLargeUploadEndpoint(fileSize: item.fileSize) {
            let endpointResult = try await FileAnalysis.shared.getLargeFileEndpoint(cancellationToken: cancellationToken)
            try Task.checkCancellation()
            guard endpointResult.getEndpointSuccess == true,
                  let largeEndpoint = endpointResult.largeFileEndpoint else {
                return false
            }
            endpoint = largeEndpoint
        }

        let progressHandler: @Sendable (Double) -> Void = { [weak item] progress in
            Task { @MainActor in
                guard item?.status == .uploading else { return }
                item?.uploadProgress = progress
            }
        }

        let uploadResult = try await FileAnalysis.shared.uploadFile(
            fileURL: item.preparedFileURL,
            apiEndPoint: endpoint,
            cancellationToken: cancellationToken,
            progressHandler: progressHandler
        )
        return uploadResult.uploadSuccess == true
    }

    private func waitForAnalysis(_ item: DownloadScanItem, cancellationToken: FileAnalysisCancellationToken) async {
        for _ in 0..<28 {
            do {
                try Task.checkCancellation()
                let reportResult = try await FileAnalysis.shared.getFileReport(
                    sha256: item.sha256,
                    cancellationToken: cancellationToken
                )
                try Task.checkCancellation()

                if reportResult.getReportSuccess == true,
                   let stats = reportResult.lastAnalysisStats,
                   isValidResponse(stats) {
                    complete(item, with: reportResult)
                    return
                }

                try await Task.sleep(for: .seconds(10))
            } catch is CancellationError {
                return
            } catch {
                fail(item, message: error.displayMessageWithCode)
                return
            }
        }

        guard !Task.isCancelled else { return }
        fail(item, message: localizedString("error.analysis.timeout"))
    }

    private func complete(_ item: DownloadScanItem, with result: FileAnalysisResult) {
        item.analysisStats = result.lastAnalysisStats
        item.status = .success
        storeScanEntry(for: item, result: result)

        let stats = item.analysisStats
        let detections = (stats?.malicious ?? 0) + (stats?.suspicious ?? 0)
        let total = stats?.allFlags.sum { $0 } ?? 0
        let body = String(format: localizedString("downloadsmonitor.notification.detections"), detections, total)
        let userInfo = notificationUserInfo(for: item)
        Task {
            await NotificationManager.pushNotification(
                title: localizedString("downloadsmonitor.notification.complete.title"),
                subtitle: item.fileName,
                body: body,
                userInfo: userInfo
            )
        }
    }

    private func notifyUploadStarted(for item: DownloadScanItem) {
        let userInfo = notificationUserInfo(for: item)
        Task {
            await NotificationManager.pushNotification(
                title: localizedString("downloadsmonitor.notification.uploading.title"),
                subtitle: item.fileName,
                body: localizedString("downloadsmonitor.notification.uploading.body"),
                userInfo: userInfo
            )
        }
    }

    private func fail(_ item: DownloadScanItem, message: String) {
        item.errorMessage = message
        item.status = .failed
        let userInfo = notificationUserInfo(for: item)
        Task {
            await NotificationManager.pushNotification(
                title: localizedString("downloadsmonitor.notification.failed.title"),
                subtitle: item.fileName,
                body: message,
                userInfo: userInfo
            )
        }
    }

    private func notificationUserInfo(for item: DownloadScanItem) -> [String: String] {
        [
            "destination": "downloadsMonitor",
            "filePath": item.originalFileURL.path,
            "sha256": item.sha256
        ]
    }

    private func appendFailedItem(url: URL, message: String) {
        appendFailedItem(originalURL: url, preparedURL: url, message: message)
    }

    private func appendFailedItem(originalURL: URL, preparedURL: URL, message: String) {
        let item = DownloadScanItem(
            originalFileURL: originalURL,
            preparedFileURL: preparedURL,
            fileSize: fileSize(for: preparedURL),
            sha256: ""
        )
        item.status = .failed
        item.errorMessage = message
        scanItems.insert(item, at: 0)
    }

    private func isValidResponse(_ stats: FileAnalysisStats) -> Bool {
        ScanPolicy.isValidAnalysisStats(stats)
    }

    private func storeScanEntry(for item: DownloadScanItem, result: FileAnalysisResult) {
        guard item.status == .success,
              let stats = item.analysisStats else { return }

        let scanResult = ScanResult(
            malicious: stats.malicious,
            analysisDate: result.lastAnalysisDate ?? "n/a",
            reputation: result.reputation ?? -999
        )
        ScanHistoryManager.shared.addScanEntry(
            ScanEntry(scanType: .file, target: item.fileName, result: scanResult)
        )
    }

    // MARK: - Folder Access

    private func activateFolderAccess(for url: URL) {
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        securityScopedFolderURL = nil

        if url.startAccessingSecurityScopedResource() {
            securityScopedFolderURL = url
        }
    }

    private func withFolderAccess<T>(_ operation: () throws -> T) rethrows -> T {
        let accessedURL = folderURL

        if securityScopedFolderURL == accessedURL {
            return try operation()
        }

        let didStartAccessing = accessedURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                accessedURL.stopAccessingSecurityScopedResource()
            }
        }

        return try operation()
    }

    private func withFolderAccess<T>(_ operation: () async throws -> T) async rethrows -> T {
        let accessedURL = folderURL

        if securityScopedFolderURL == accessedURL {
            return try await operation()
        }

        let didStartAccessing = accessedURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                accessedURL.stopAccessingSecurityScopedResource()
            }
        }

        return try await operation()
    }

    private func saveSecurityScopedBookmark(for url: URL) {
        do {
            Defaults[.autoScanDownloadsFolderBookmark] = try SecurityScopedBookmark.encodedString(for: url)
        } catch {
            Defaults[.autoScanDownloadsFolderBookmark] = ""
            log.error("Downloads monitor failed to save folder bookmark: \(error)")
        }
    }

    private static func bookmarkedFolderURL() -> URL? {
        let bookmark = Defaults[.autoScanDownloadsFolderBookmark]
        guard !bookmark.isEmpty,
              let data = Data(base64Encoded: bookmark) else { return nil }

        do {
            return try resolveBookmarkedFolderURL(from: data, options: .withSecurityScope)
        } catch {
            do {
                return try resolveBookmarkedFolderURL(from: data, options: [])
            } catch {
                log.error("Downloads monitor failed to restore folder bookmark: \(error)")
                return nil
            }
        }
    }

    private static func resolveBookmarkedFolderURL(
        from data: Data,
        options: URL.BookmarkResolutionOptions
    ) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        if isStale {
            let bookmarkOptions: URL.BookmarkCreationOptions = options.contains(.withSecurityScope)
                ? [.withSecurityScope, .securityScopeAllowOnlyReadAccess]
                : []
            let refreshedData = try url.bookmarkData(
                options: bookmarkOptions,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            Defaults[.autoScanDownloadsFolderBookmark] = refreshedData.base64EncodedString()
        }

        return url
    }

    // MARK: - File Helpers

    private func eligibleFileURLs() throws -> [URL] {
        let urls = try FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        )
        return urls.filter { isEligibleFileURL($0) }
    }

    private func isEligibleFileURL(_ url: URL) -> Bool {
        guard !ScanPolicy.isActiveDownloadExtension(url.pathExtension) else { return false }
        guard !hasActiveDownloadMarker(for: url) else { return false }

        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey, .isPackageKey])
            let isAppBundle = values.isPackage == true && url.pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame
            guard values.isRegularFile == true || isAppBundle else { return false }
            return selectedFileCategories.contains(category(for: url, isAppBundle: isAppBundle))
        } catch {
            log.error("Downloads monitor failed to inspect \(url.path): \(error)")
        }

        return false
    }

    private func hasActiveDownloadMarker(for url: URL) -> Bool {
        let folderURL = url.deletingLastPathComponent()
        let fileName = url.lastPathComponent

        return ScanPolicy.activeDownloadExtensions.contains { fileExtension in
            let markerURL = folderURL.appendingPathComponent("\(fileName).\(fileExtension)")
            return FileManager.default.fileExists(atPath: markerURL.path)
        }
    }

    private func category(for url: URL, isAppBundle: Bool) -> DownloadMonitorFileCategory {
        ScanPolicy.category(forFilenameExtension: url.pathExtension, isAppBundle: isAppBundle)
    }

    private func waitForStableFile(at url: URL) async -> URL? {
        var lastFingerprint: String?
        var unchangedChecks = 0

        for _ in 0..<8 {
            guard !Task.isCancelled else { return nil }
            guard !hasActiveDownloadMarker(for: url), fileSize(for: url) > 0 else {
                try? await Task.sleep(for: .seconds(3))
                continue
            }

            let currentFingerprint = fileFingerprint(for: url)
            if currentFingerprint == lastFingerprint {
                unchangedChecks += 1
            } else {
                lastFingerprint = currentFingerprint
                unchangedChecks = 1
            }

            if unchangedChecks >= 3 && secondsSinceLastModification(for: url) >= 10 {
                return url
            }

            try? await Task.sleep(for: .seconds(3))
        }

        return nil
    }

    private func fileFingerprint(for url: URL) -> String {
        ScanPolicy.fileFingerprint(for: url)
    }

    private func secondsSinceLastModification(for url: URL) -> TimeInterval {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            guard let modificationDate = attributes[.modificationDate] as? Date else { return 0 }
            return Date().timeIntervalSince(modificationDate)
        } catch {
            return 0
        }
    }

    private func fileSize(for url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }

    private func sha256(for url: URL) async throws -> String {
        try await FileHasher.sha256Async(for: url)
    }

    private func monitoringMessage(for folderURL: URL) -> String {
        String(format: localizedString("downloadsmonitor.status.monitoring_folder"), folderURL.path)
    }

    private func cannotReadFolderMessage(_ error: Error) -> String {
        String(format: localizedString("downloadsmonitor.status.cannot_read_folder"), error.localizedDescription)
    }

    private func queuedMessage(for fileURL: URL) -> String {
        String(format: localizedString("downloadsmonitor.status.queued"), fileURL.lastPathComponent)
    }

    private func localErrorMessage(_ error: Error) -> String {
        String(format: localizedString("downloadsmonitor.error.local"), error.displayMessageWithCode)
    }

    private func localizedString(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func isActiveStatus(_ status: DownloadScanStatus) -> Bool {
        switch status {
        case .queued, .preparing, .uploading, .analyzing:
            true
        case .success, .failed:
            false
        }
    }

    private static var savedFolderURL: URL {
        if let bookmarkedURL = bookmarkedFolderURL() {
            return bookmarkedURL
        }

        let savedPath = Defaults[.autoScanDownloadsFolderPath]
        if !savedPath.isEmpty {
            return URL(filePath: savedPath, directoryHint: .isDirectory)
        }

        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
    }
}

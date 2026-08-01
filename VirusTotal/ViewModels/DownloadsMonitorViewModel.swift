//
//  DownloadsMonitorViewModel.swift
//  VirusTotal
//

import CryptoKit
import Defaults
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class DownloadScanItem: Identifiable {
    let id = UUID()
    let fileURL: URL
    let fileName: String
    let fileSize: Int64
    let sha256: String

    var status: DownloadScanStatus = .queued
    var uploadProgress: Double = 0
    var analysisStats: FileAnalysisStats?
    var errorMessage: String?

    init(fileURL: URL, fileSize: Int64, sha256: String) {
        self.fileURL = fileURL
        self.fileName = fileURL.lastPathComponent
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
    var statusMessage: String = "Monitoring is off"
    var selectedFilePath: String?
    var selectedFileCategories: Set<DownloadMonitorFileCategory> = Set(Defaults[.downloadMonitorFileCategories])

    var hasSavedFolderAccess: Bool {
        !Defaults[.autoScanDownloadsFolderBookmark].isEmpty
    }

    private var monitorTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?
    private var knownFileFingerprints: [String: String] = [:]
    private var queuedFileFingerprints: Set<String> = []
    private var securityScopedFolderURL: URL?
    private let maxFileSize: Int64 = 681_574_400
    private let defaultUploadURL = "https://www.virustotal.com/api/v3/files"

    private init() {}

    func startIfNeeded() {
        isEnabled = Defaults[.autoScanDownloadsEnabled] && hasSavedFolderAccess
        Defaults[.autoScanDownloadsEnabled] = isEnabled
        folderURL = Self.savedFolderURL
        guard isEnabled else {
            stopMonitoring()
            return
        }

        startMonitoring()
    }

    func setMonitoringEnabled(_ enabled: Bool) {
        guard !enabled || hasSavedFolderAccess else {
            isEnabled = false
            Defaults[.autoScanDownloadsEnabled] = false
            statusMessage = "Choose a folder to start monitoring"
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
        saveSecurityScopedBookmark(for: url)
        Defaults[.autoScanDownloadsFolderPath] = url.path
        folderURL = url
        activateFolderAccess(for: url)
        knownFileFingerprints.removeAll()
        queuedFileFingerprints.removeAll()

        if isEnabled {
            startMonitoring()
        }
    }

    func scanExistingFiles() {
        Task {
            await scanFolder(includeKnownFiles: true)
            startScanQueueIfNeeded()
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

        if let index = scanItems.firstIndex(where: { $0.fileURL.path == filePath }) {
            let item = scanItems.remove(at: index)
            scanItems.insert(item, at: 0)
        }
    }

    func eligibleFileCount() -> Int {
        do {
            return try eligibleFileURLs().count
        } catch {
            statusMessage = "Cannot read folder: \(error.localizedDescription)"
            log.error("Downloads monitor failed to count folder files: \(error)")
            return 0
        }
    }

    func clearResults() {
        scanItems.removeAll()
    }

    // MARK: - Monitoring

    private func startMonitoring() {
        stopMonitoring()
        activateFolderAccess(for: folderURL)
        statusMessage = "Monitoring new files in \(folderURL.path)"

        Task {
            await NotificationManager.requestAuthorization()
        }

        monitorTask = Task { [weak self] in
            guard let self else { return }
            self.snapshotCurrentFiles()

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(10))
                await self.scanFolder(includeKnownFiles: false)
                self.startScanQueueIfNeeded()
            }
        }
    }

    private func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
        securityScopedFolderURL?.stopAccessingSecurityScopedResource()
        securityScopedFolderURL = nil
        statusMessage = "Monitoring is off"
    }

    private func snapshotCurrentFiles() {
        do {
            knownFileFingerprints = Dictionary(
                uniqueKeysWithValues: try eligibleFileURLs().map { ($0.path, fileFingerprint(for: $0)) }
            )
            if isEnabled {
                statusMessage = "Monitoring new files in \(folderURL.path)"
            }
        } catch {
            statusMessage = "Cannot read folder: \(error.localizedDescription)"
            log.error("Downloads monitor failed to snapshot folder: \(error)")
        }
    }

    private func scanFolder(includeKnownFiles: Bool) async {
        let urls: [URL]
        do {
            urls = try eligibleFileURLs()
        } catch {
            statusMessage = "Cannot read folder: \(error.localizedDescription)"
            log.error("Downloads monitor failed to read folder: \(error)")
            return
        }

        for url in urls {
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

    private func queueFileIfNeeded(_ url: URL) async -> Bool {
        guard let stableURL = await waitForStableFile(at: url) else { return false }
        let fingerprint = fileFingerprint(for: stableURL)
        guard !queuedFileFingerprints.contains(fingerprint) else { return true }

        let preparedURL: URL
        do {
            preparedURL = try await FilePreparation.scanFileURL(for: stableURL)
        } catch {
            appendFailedItem(url: stableURL, message: "Local Error: \(error.displayMessageWithCode)")
            return true
        }

        let fileSize = fileSize(for: preparedURL)
        guard fileSize > 0 && fileSize < maxFileSize else {
            appendFailedItem(url: preparedURL, message: "File size exceeds 650 MB or is invalid")
            return true
        }

        do {
            let sha256 = try sha256(for: preparedURL)
            queuedFileFingerprints.insert(fingerprint)
            scanItems.insert(DownloadScanItem(fileURL: preparedURL, fileSize: fileSize, sha256: sha256), at: 0)
            statusMessage = "Queued \(stableURL.lastPathComponent)"
            return true
        } catch {
            appendFailedItem(url: preparedURL, message: "Failed to calculate SHA256")
            return true
        }
    }

    private func startScanQueueIfNeeded() {
        guard scanTask == nil else { return }

        scanTask = Task { [weak self] in
            guard let self else { return }
            await self.processQueuedItems()
            await MainActor.run {
                self.scanTask = nil
            }
        }
    }

    // MARK: - Scanning

    private func processQueuedItems() async {
        while let item = scanItems.reversed().first(where: { $0.status == .queued }) {
            await process(item)
        }
    }

    private func process(_ item: DownloadScanItem) async {
        item.status = .preparing

        do {
            let reportResult = try await FileAnalysis.shared.getFileReport(sha256: item.sha256)
            if reportResult.getReportSuccess == true,
               let stats = reportResult.lastAnalysisStats,
               isValidResponse(stats) {
                complete(item, with: reportResult)
                return
            }

            guard reportResult.statusMonitor != .fail else {
                fail(item, message: reportResult.errorMessage ?? "Failed to get file report")
                return
            }

            item.status = .uploading
            notifyUploadStarted(for: item)
            if try await upload(item) {
                item.status = .analyzing
                try await Task.sleep(for: .seconds(20))
                await waitForAnalysis(item)
            } else {
                fail(item, message: "Upload failed")
            }
        } catch {
            fail(item, message: error.displayMessageWithCode)
        }
    }

    private func upload(_ item: DownloadScanItem) async throws -> Bool {
        var endpoint = defaultUploadURL
        if item.fileSize > 33_554_432 {
            let endpointResult = try await FileAnalysis.shared.getLargeFileEndpoint()
            guard endpointResult.getEndpointSuccess == true,
                  let largeEndpoint = endpointResult.largeFileEndpoint else {
                return false
            }
            endpoint = largeEndpoint
        }

        let progressHandler: @Sendable (Double) -> Void = { [weak item] progress in
            Task { @MainActor in
                item?.uploadProgress = progress
            }
        }

        let uploadResult = try await FileAnalysis.shared.uploadFile(
            fileURL: item.fileURL,
            apiEndPoint: endpoint,
            progressHandler: progressHandler
        )
        return uploadResult.uploadSuccess == true
    }

    private func waitForAnalysis(_ item: DownloadScanItem) async {
        for _ in 0..<28 {
            do {
                let reportResult = try await FileAnalysis.shared.getFileReport(sha256: item.sha256)
                if reportResult.getReportSuccess == true,
                   let stats = reportResult.lastAnalysisStats,
                   isValidResponse(stats) {
                    complete(item, with: reportResult)
                    return
                }

                try await Task.sleep(for: .seconds(10))
            } catch {
                fail(item, message: error.displayMessageWithCode)
                return
            }
        }

        fail(item, message: "Analysis timeout")
    }

    private func complete(_ item: DownloadScanItem, with result: FileAnalysisResult) {
        item.analysisStats = result.lastAnalysisStats
        item.status = .success
        storeScanEntry(for: item, result: result)

        let stats = item.analysisStats
        let detections = (stats?.malicious ?? 0) + (stats?.suspicious ?? 0)
        let total = stats?.allFlags.sum { $0 } ?? 0
        let body = "\(detections)/\(total) detections"
        let userInfo = notificationUserInfo(for: item)
        Task {
            await NotificationManager.pushNotification(
                title: "Downloads scan complete",
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
                title: "Uploading to VirusTotal",
                subtitle: item.fileName,
                body: "The app is uploading this file. Please wait.",
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
                title: "Downloads scan failed",
                subtitle: item.fileName,
                body: message,
                userInfo: userInfo
            )
        }
    }

    private func notificationUserInfo(for item: DownloadScanItem) -> [String: String] {
        [
            "destination": "downloadsMonitor",
            "filePath": item.fileURL.path,
            "sha256": item.sha256
        ]
    }

    private func appendFailedItem(url: URL, message: String) {
        let item = DownloadScanItem(fileURL: url, fileSize: fileSize(for: url), sha256: "")
        item.status = .failed
        item.errorMessage = message
        scanItems.insert(item, at: 0)
    }

    private func isValidResponse(_ stats: FileAnalysisStats) -> Bool {
        stats.allFlags.sum { $0 } > 0
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

    private func saveSecurityScopedBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            Defaults[.autoScanDownloadsFolderBookmark] = data.base64EncodedString()
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
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            return url
        } catch {
            log.error("Downloads monitor failed to restore folder bookmark: \(error)")
            return nil
        }
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
        let excludedExtensions = ["download", "crdownload", "part", "tmp"]
        guard !excludedExtensions.contains(url.pathExtension.lowercased()) else { return false }

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

    private func category(for url: URL, isAppBundle: Bool) -> DownloadMonitorFileCategory {
        if isAppBundle { return .applications }

        guard let type = UTType(filenameExtension: url.pathExtension) else {
            return .other
        }

        if type.conforms(to: .archive) { return .archives }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .application) { return .applications }
        if type.conforms(to: .text) ||
            type.conforms(to: .pdf) ||
            type.conforms(to: .rtf) ||
            type.conforms(to: .html) ||
            type.conforms(to: .xml) ||
            type.conforms(to: .json) ||
            type.conforms(to: .sourceCode) ||
            type.conforms(to: .script) ||
            type.conforms(to: .propertyList) {
            return .documents
        }

        return .other
    }

    private func waitForStableFile(at url: URL) async -> URL? {
        var lastSize: Int64 = -1

        for _ in 0..<5 {
            let currentSize = fileSize(for: url)
            guard currentSize > 0 else {
                try? await Task.sleep(for: .seconds(2))
                continue
            }

            if currentSize == lastSize {
                return url
            }

            lastSize = currentSize
            try? await Task.sleep(for: .seconds(2))
        }

        return nil
    }

    private func fileFingerprint(for url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            let modificationDate = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            return "\(url.path)|\(size)|\(modificationDate)"
        } catch {
            return url.path
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

    private func sha256(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
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

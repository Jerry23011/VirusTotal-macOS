//
//  UtilitiesTests.swift
//  VirusTotalTests
//

import AppKit
import Defaults
import Foundation
import Testing
@testable import VirusTotal

@Suite("Utilities")
struct UtilitiesTests {
    @Test("SHA256 fingerprint is stable")
    func sha256Fingerprint() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try "VirusTotal".write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(try FileHasher.sha256(for: fileURL) == "275cfe1cdf4b59ba602a6663462bde0a5dcd7f41a3eaba11f6e6ec95f970383b")
    }

    @Test("Security-scoped bookmark helper restores the selected folder URL")
    func securityScopedBookmarkRoundTrip() throws {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folderURL) }

        let encodedBookmark = try SecurityScopedBookmark.encodedString(for: folderURL)
        let restoredURL = try #require(try SecurityScopedBookmark.resolveURL(from: encodedBookmark))

        #expect(restoredURL.standardizedFileURL.path == folderURL.standardizedFileURL.path)
    }
}

@MainActor
@Suite("App behavior")
struct AppBehaviorTests {
    @Test("Batch cancellation resets active files")
    func batchCancellationResetsActiveFiles() {
        let viewModel = FileBatchViewModel()
        let uploadingFile = BatchFile(fileURL: URL(filePath: "/tmp/a"), fileName: "a", fileSize: 1, sha256: "a")
        let analyzingFile = BatchFile(fileURL: URL(filePath: "/tmp/b"), fileName: "b", fileSize: 1, sha256: "b")
        let completedFile = BatchFile(fileURL: URL(filePath: "/tmp/c"), fileName: "c", fileSize: 1, sha256: "c")
        uploadingFile.status = .uploading
        analyzingFile.status = .analyzing
        completedFile.status = .success
        viewModel.batchFiles = [uploadingFile, analyzingFile, completedFile]
        viewModel.isProcessing = true
        viewModel.overallProgress = 0.5

        viewModel.cancelAllProcessing()

        #expect(!viewModel.isProcessing)
        #expect(uploadingFile.status == .pending)
        #expect(analyzingFile.status == .pending)
        #expect(completedFile.status == .success)
        #expect(viewModel.overallProgress == 0)
    }

    @Test("Background mode keeps the app alive when the last window closes")
    func backgroundModeKeepsAppAlive() {
        let appDelegate = AppDelegate()

        #expect(!appDelegate.applicationShouldTerminateAfterLastWindowClosed(NSApp))
    }

    @Test("Disabling downloads monitor completes queued items")
    func disablingDownloadsMonitorCompletesQueuedItems() {
        let viewModel = DownloadsMonitorViewModel.shared
        let oldEnabled = viewModel.isEnabled
        let oldDefaultEnabled = Defaults[.autoScanDownloadsEnabled]
        defer {
            viewModel.scanItems.removeAll()
            viewModel.isEnabled = oldEnabled
            Defaults[.autoScanDownloadsEnabled] = oldDefaultEnabled
        }

        let item = DownloadScanItem(
            originalFileURL: URL(filePath: "/tmp/queued.zip"),
            preparedFileURL: URL(filePath: "/tmp/queued.zip"),
            fileSize: 1,
            sha256: "1"
        )
        viewModel.scanItems = [item]
        viewModel.isEnabled = true

        viewModel.setMonitoringEnabled(false)

        #expect(item.status == .failed)
        #expect(!viewModel.hasActiveScanItems)

        viewModel.clearResults()

        #expect(viewModel.scanItems.isEmpty)
    }

    @Test("Notification file selection moves the item to the top")
    func notificationSelectionMovesItemToTop() {
        let viewModel = DownloadsMonitorViewModel.shared
        defer {
            viewModel.scanItems.removeAll()
            viewModel.selectedFilePath = nil
        }

        let first = DownloadScanItem(
            originalFileURL: URL(filePath: "/tmp/first.zip"),
            preparedFileURL: URL(filePath: "/tmp/first.zip"),
            fileSize: 1,
            sha256: "1"
        )
        let second = DownloadScanItem(
            originalFileURL: URL(filePath: "/tmp/second.zip"),
            preparedFileURL: URL(filePath: "/tmp/second.zip"),
            fileSize: 1,
            sha256: "2"
        )
        viewModel.scanItems = [first, second]

        viewModel.handleNotificationSelection(filePath: second.originalFileURL.path)

        #expect(viewModel.selectedFilePath == second.originalFileURL.path)
        #expect(viewModel.scanItems.first?.id == second.id)
    }

    @Test("Language preference applies to AppleLanguages")
    func languagePreferenceAppliesToAppleLanguages() {
        let defaults = UserDefaults.standard
        let oldLanguages = defaults.array(forKey: "AppleLanguages")
        defer {
            if let oldLanguages {
                defaults.set(oldLanguages, forKey: "AppleLanguages")
            } else {
                defaults.removeObject(forKey: "AppleLanguages")
            }
        }

        AppLanguage.russian.apply()

        #expect(defaults.stringArray(forKey: "AppleLanguages")?.first == "ru")
    }
}

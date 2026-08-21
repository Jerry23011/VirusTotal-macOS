//
//  DownloadsMonitorTests.swift
//  VirusTotalTests
//

import Defaults
import Foundation
import Testing
@testable import VirusTotal

@MainActor
@Suite("Downloads monitor")
struct DownloadsMonitorTests {
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
@Suite("Downloads monitor state")
struct DownloadsMonitorStateTests {
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
}

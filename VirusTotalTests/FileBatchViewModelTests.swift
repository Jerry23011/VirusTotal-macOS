//
//  FileBatchViewModelTests.swift
//  VirusTotalTests
//

import Foundation
import Testing
@testable import VirusTotal

@MainActor
@Suite("File batch view model")
struct FileBatchViewModelTests {
    @Test("Cancelling a batch resets files that were still in flight")
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

    @Test("A file still being prepared blocks Start and is dropped by Clear")
    func clearingDuringPreparationDropsTheFile() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = try makeLargeFile(in: directory)

        let viewModel = FileBatchViewModel()
        let adding = Task { await viewModel.addFiles([fileURL]) }
        for _ in 0..<1_000 where !viewModel.isPreparingFiles {
            await Task.yield()
        }
        try #require(viewModel.isPreparingFiles)

        await viewModel.startBatchAnalysis()
        #expect(!viewModel.isProcessing)

        viewModel.clearAllFiles()
        await adding.value

        #expect(viewModel.batchFiles.isEmpty)
        #expect(!viewModel.isPreparingFiles)
    }

    @Test("Clear cancels the entire multi-file import, including files not yet prepared")
    func clearingStopsRemainingImportedFiles() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try makeLargeFile(in: directory)
        let second = directory.appendingPathComponent("second.txt")
        try Data("second".utf8).write(to: second)
        let viewModel = FileBatchViewModel()
        let adding = Task { await viewModel.addFiles([first, second]) }
        for _ in 0..<1_000 where !viewModel.isPreparingFiles { await Task.yield() }
        try #require(viewModel.isPreparingFiles)
        viewModel.clearAllFiles()
        await adding.value
        #expect(viewModel.batchFiles.isEmpty)
        #expect(!viewModel.isPreparingFiles)
    }

    @Test("Adding the same file twice at once keeps one entry")
    func concurrentDuplicateIsIgnored() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = try makeLargeFile(in: directory)

        let viewModel = FileBatchViewModel()
        let first = Task { await viewModel.addFiles([fileURL]) }
        let second = Task { await viewModel.addFiles([fileURL]) }
        await first.value
        await second.value

        #expect(viewModel.batchFiles.count == 1)
        #expect(viewModel.batchFiles.first?.sha256.isEmpty == false)
    }

    /// Large enough that hashing it outlasts a few scheduler hops.
    private func makeLargeFile(in directory: URL) throws -> URL {
        let fileURL = directory.appendingPathComponent("large.bin")
        try Data(count: 32 * 1024 * 1024).write(to: fileURL)
        return fileURL
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

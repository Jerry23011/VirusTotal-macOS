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
}

//
//  ScanPolicyTests.swift
//  VirusTotalTests
//

import Foundation
import Testing
import UniformTypeIdentifiers
@testable import VirusTotal

@Suite("Scan policy")
struct ScanPolicyTests {
    @Test("Temporary download extensions are filtered")
    func temporaryDownloadExtensionsAreFiltered() {
        #expect(ScanPolicy.isActiveDownloadExtension("download"))
        #expect(ScanPolicy.isActiveDownloadExtension("CRDOWNLOAD"))
        #expect(ScanPolicy.isActiveDownloadExtension("part"))
        #expect(!ScanPolicy.isActiveDownloadExtension("zip"))
    }

    @Test("UTType categories are classified")
    func utTypesAreClassified() {
        #expect(ScanPolicy.category(for: .zip) == .archives)
        #expect(ScanPolicy.category(for: .png) == .images)
        #expect(ScanPolicy.category(for: .mp3) == .audio)
        #expect(ScanPolicy.category(for: .mpeg4Movie) == .video)
        #expect(ScanPolicy.category(for: .pdf) == .documents)
        #expect(ScanPolicy.category(forFilenameExtension: "app", isAppBundle: true) == .applications)
    }

    @Test("File fingerprints include path, size, and modification time")
    func fingerprintIncludesPathSizeAndModificationTime() {
        let fingerprint = ScanPolicy.fileFingerprint(
            path: "/tmp/sample.zip",
            fileSize: 42,
            modificationDate: 1_720_000_000
        )

        #expect(fingerprint == "/tmp/sample.zip|42|1720000000.0")
    }

    @Test("650 MB upload limit is enforced")
    func uploadSizeLimitIsEnforced() {
        #expect(!ScanPolicy.isSupportedFileSize(0))
        #expect(ScanPolicy.isSupportedFileSize(ScanPolicy.maxUploadSize - 1))
        #expect(ScanPolicy.isSupportedFileSize(ScanPolicy.maxUploadSize))
        #expect(!ScanPolicy.isSupportedFileSize(ScanPolicy.maxUploadSize + 1))
    }

    @Test("Upload endpoint selection uses the large endpoint only above threshold")
    func uploadEndpointSelection() {
        #expect(ScanPolicy.uploadEndpoint(forFileSize: 1) == ScanPolicy.defaultUploadEndpoint)
        #expect(ScanPolicy.uploadEndpoint(forFileSize: ScanPolicy.largeUploadThreshold) == ScanPolicy.defaultUploadEndpoint)
        #expect(ScanPolicy.requiresLargeUploadEndpoint(fileSize: ScanPolicy.largeUploadThreshold + 1))
        #expect(ScanPolicy.uploadEndpoint(
            forFileSize: ScanPolicy.largeUploadThreshold + 1,
            largeFileEndpoint: "https://upload.example.test"
        ) == "https://upload.example.test")
        #expect(ScanPolicy.requiresLargeUploadEndpoint(fileSize: ScanPolicy.maxUploadSize))
        #expect(ScanPolicy.uploadEndpoint(
            forFileSize: ScanPolicy.maxUploadSize,
            largeFileEndpoint: "https://upload.example.test"
        ) == "https://upload.example.test")
        #expect(ScanPolicy.uploadEndpoint(forFileSize: ScanPolicy.maxUploadSize + 1) == "")
    }

    @Test("Polling stops after configured retry count")
    func pollingLimit() {
        #expect(ScanPolicy.shouldContinuePolling(attempt: 0))
        #expect(ScanPolicy.shouldContinuePolling(attempt: ScanPolicy.maxPollingAttempts - 1))
        #expect(!ScanPolicy.shouldContinuePolling(attempt: ScanPolicy.maxPollingAttempts))
    }

    @Test("Empty analysis stats are treated as in-progress")
    func emptyAnalysisStatsAreInvalid() {
        let emptyStats = FileAnalysisStats(
            malicious: 0,
            suspicious: 0,
            undetected: 0,
            harmless: 0,
            timeout: 0,
            confirmedTimeout: 0,
            failure: 0,
            typeUnsupported: 0
        )
        let completeStats = FileAnalysisStats(
            malicious: 1,
            suspicious: 0,
            undetected: 0,
            harmless: 0,
            timeout: 0,
            confirmedTimeout: 0,
            failure: 0,
            typeUnsupported: 0
        )

        #expect(!ScanPolicy.isValidAnalysisStats(emptyStats))
        #expect(ScanPolicy.isValidAnalysisStats(completeStats))
    }

    @Test("A completed analysis stops the wait immediately")
    func completedAnalysisFinishes() {
        #expect(ScanPolicy.analysisPollDecision(status: "completed", attempt: 0) == .finished)
        #expect(ScanPolicy.analysisPollDecision(status: "completed",
                                                attempt: ScanPolicy.maxPollingAttempts) == .finished)
    }

    @Test("A queued or running analysis keeps the caller waiting")
    func queuedAnalysisKeepsWaiting() {
        #expect(ScanPolicy.analysisPollDecision(status: "queued", attempt: 0) == .keepWaiting)
        #expect(ScanPolicy.analysisPollDecision(status: "in-progress", attempt: 5) == .keepWaiting)
    }

    @Test("A missing or unknown status is treated as still running")
    func unknownStatusKeepsWaiting() {
        #expect(ScanPolicy.analysisPollDecision(status: nil, attempt: 0) == .keepWaiting)
        #expect(ScanPolicy.analysisPollDecision(status: "", attempt: 0) == .keepWaiting)
        #expect(ScanPolicy.analysisPollDecision(status: "something-new", attempt: 0) == .keepWaiting)
    }

    @Test("Waiting for an analysis gives up once the polling budget runs out")
    func analysisPollingIsBounded() {
        #expect(ScanPolicy.analysisPollDecision(status: "queued",
                                                attempt: ScanPolicy.maxPollingAttempts - 1) == .keepWaiting)
        #expect(ScanPolicy.analysisPollDecision(status: "queued",
                                                attempt: ScanPolicy.maxPollingAttempts) == .timedOut)
    }
}

//
//  FileHasherTests.swift
//  VirusTotalTests
//

import Foundation
import Testing
@testable import VirusTotal

@Suite("File hasher")
struct FileHasherTests {
    @Test("Async SHA-256 matches synchronous SHA-256")
    func asyncSHA256MatchesSynchronousSHA256() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("sample.bin")
        let data = Data((0..<16_384).map { UInt8($0 % 251) })
        try data.write(to: fileURL)

        let synchronousHash = try FileHasher.sha256(for: fileURL)
        let asynchronousHash = try await FileHasher.sha256Async(for: fileURL)

        #expect(asynchronousHash == synchronousHash)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

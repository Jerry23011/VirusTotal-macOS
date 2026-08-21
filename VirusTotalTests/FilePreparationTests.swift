//
//  FilePreparationTests.swift
//  VirusTotalTests
//

import Foundation
import Testing
@testable import VirusTotal

@Suite("File preparation")
struct FilePreparationTests {
    @Test(".app bundles are detected and prepared as ZIP archives")
    func appBundleIsZipped() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let appURL = directory.appendingPathComponent("Sample.app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contentsURL, withIntermediateDirectories: true)
        try "plist".write(
            to: contentsURL.appendingPathComponent("Info.plist"),
            atomically: true,
            encoding: .utf8
        )

        #expect(try FilePreparation.needsZipArchive(for: appURL))
        #expect(try FilePreparation.preparedFileName(for: appURL) == "Sample.app.zip")

        let archiveURL = try await FilePreparation.scanFileURL(for: appURL)
        defer { FilePreparation.cleanupPreparedFile(at: archiveURL) }

        #expect(archiveURL.pathExtension == "zip")
        #expect(FileManager.default.fileExists(atPath: archiveURL.path))
    }

    @Test("Regular files are not zipped")
    func regularFileIsNotZipped() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let fileURL = directory.appendingPathComponent("sample.txt")
        try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

        #expect(try !FilePreparation.needsZipArchive(for: fileURL))
        #expect(try FilePreparation.preparedFileName(for: fileURL) == "sample.txt")
        #expect(try await FilePreparation.scanFileURL(for: fileURL) == fileURL)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

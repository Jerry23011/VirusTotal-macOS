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

        #expect(archiveURL.lastPathComponent == "Sample.app.zip")
        let archiveData = try Data(contentsOf: archiveURL)
        #expect(archiveData.starts(with: [0x50, 0x4B, 0x03, 0x04])) // ZIP local file header
    }

    @Test("Cleanup removes the archive directory it created")
    func cleanupRemovesOwnArchive() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let appURL = directory.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

        let archiveURL = try await FilePreparation.scanFileURL(for: appURL)
        FilePreparation.cleanupPreparedFile(at: archiveURL)

        #expect(!FileManager.default.fileExists(atPath: archiveURL.deletingLastPathComponent().path))
    }

    @Test("Cleanup leaves files it did not create alone, even under its root")
    func cleanupIgnoresForeignFiles() throws {
        let archiveRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("VirusTotalAppArchives", isDirectory: true)
        let foreignDirectory = archiveRoot.appendingPathComponent("user-files-\(UUID().uuidString)", isDirectory: true)
        let uuidDirectory = archiveRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: foreignDirectory)
            try? FileManager.default.removeItem(at: uuidDirectory)
        }
        try FileManager.default.createDirectory(at: foreignDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: uuidDirectory, withIntermediateDirectories: true)

        let zipOutsideUUIDDirectory = foreignDirectory.appendingPathComponent("archive.zip")
        let nonZipInUUIDDirectory = uuidDirectory.appendingPathComponent("sample.txt")
        try "zip".write(to: zipOutsideUUIDDirectory, atomically: true, encoding: .utf8)
        try "txt".write(to: nonZipInUUIDDirectory, atomically: true, encoding: .utf8)

        FilePreparation.cleanupPreparedFile(at: zipOutsideUUIDDirectory)
        FilePreparation.cleanupPreparedFile(at: nonZipInUUIDDirectory)

        #expect(FileManager.default.fileExists(atPath: zipOutsideUUIDDirectory.path))
        #expect(FileManager.default.fileExists(atPath: nonZipInUUIDDirectory.path))
    }

    @Test("A foreign ZIP in a UUID directory is never removed")
    func cleanupIgnoresForeignZip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("VirusTotalAppArchives")
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("foreign.zip")
        try Data("user data".utf8).write(to: file)
        FilePreparation.cleanupPreparedFile(at: file)
        #expect(FileManager.default.fileExists(atPath: file.path))
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

//
//  FilePreparation.swift
//  VirusTotal
//

import Foundation

enum FilePreparation {
    private static let archiveRootDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("VirusTotalAppArchives", isDirectory: true)

    static func scanFileURL(for fileURL: URL) async throws -> URL {
        guard try needsZipArchive(for: fileURL) else {
            return fileURL
        }

        cleanupOldTemporaryArchives()
        return try await makeZipArchive(for: fileURL)
    }

    static func cleanupPreparedFile(at fileURL: URL) {
        guard temporaryArchiveDirectory(for: fileURL) != nil else { return }

        let directoryURL = fileURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    static func needsZipArchive(for fileURL: URL) throws -> Bool {
        try fileURL.isAppBundle
    }

    static func preparedFileName(for fileURL: URL) throws -> String {
        try needsZipArchive(for: fileURL)
            ? fileURL.lastPathComponent + ".zip"
            : fileURL.lastPathComponent
    }

    private static func makeZipArchive(for appBundleURL: URL) async throws -> URL {
        try Task.checkCancellation()
        let processBox = CancellableProcessBox()
        let archiveTask = Task.detached(priority: .userInitiated) {
            try createZipArchive(for: appBundleURL, processBox: processBox)
        }

        return try await withTaskCancellationHandler {
            try await archiveTask.value
        } onCancel: {
            archiveTask.cancel()
            processBox.cancel()
        }
    }

    private static func createZipArchive(for appBundleURL: URL, processBox: CancellableProcessBox) throws -> URL {
        try Task.checkCancellation()
        let archiveDirectory = archiveRootDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)
        } catch {
            try? FileManager.default.removeItem(at: archiveDirectory)
            throw error
        }

        let archiveURL = archiveDirectory
            .appendingPathComponent(appBundleURL.lastPathComponent)
            .appendingPathExtension("zip")
        var shouldKeepArchive = false
        defer {
            if !shouldKeepArchive {
                try? FileManager.default.removeItem(at: archiveDirectory)
            }
        }

        let process = Process()
        process.executableURL = URL(filePath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--keepParent",
            appBundleURL.path,
            archiveURL.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try processBox.set(process)
        defer { processBox.clear(process) }
        try process.run()
        process.waitUntilExit()
        try Task.checkCancellation()

        guard process.terminationStatus == 0 else {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let details = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = details?.isEmpty == false
                ? "Failed to create .app.zip archive: \(details!)"
                : "Failed to create .app.zip archive."
            throw NSError(
                domain: "VirusTotal.FilePreparation",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: message]
            )
        }

        shouldKeepArchive = true
        return archiveURL
    }

    private static func cleanupOldTemporaryArchives() {
        guard let archiveDirectories = try? FileManager.default.contentsOfDirectory(
            at: archiveRootDirectory,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        let expirationDate = Date().addingTimeInterval(-24 * 60 * 60)
        for archiveDirectory in archiveDirectories {
            let creationDate = (try? archiveDirectory.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            if creationDate < expirationDate {
                try? FileManager.default.removeItem(at: archiveDirectory)
            }
        }
    }

    private static func temporaryArchiveDirectory(for fileURL: URL) -> URL? {
        let standardizedRoot = archiveRootDirectory.standardizedFileURL.path
        let standardizedURL = fileURL.standardizedFileURL
        guard standardizedURL.path.hasPrefix(standardizedRoot + "/") else { return nil }

        return standardizedURL.deletingLastPathComponent()
    }
}

private final class CancellableProcessBox: @unchecked Sendable {
    private let lock = NSLock()
    private var process: Process?
    private var isCancelled = false

    func set(_ process: Process) throws {
        lock.lock()
        if isCancelled {
            lock.unlock()
            process.terminate()
            throw CancellationError()
        }

        self.process = process
        lock.unlock()
    }

    func clear(_ process: Process) {
        lock.lock()
        if self.process === process {
            self.process = nil
        }
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        isCancelled = true
        let process = process
        self.process = nil
        lock.unlock()

        process?.terminate()
    }
}

private extension URL {
    var isAppBundle: Bool {
        get throws {
            guard pathExtension.localizedCaseInsensitiveCompare("app") == .orderedSame else {
                return false
            }

            let resourceValues = try resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
            return resourceValues.isDirectory == true || resourceValues.isPackage == true
        }
    }
}

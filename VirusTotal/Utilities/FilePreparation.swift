//
//  FilePreparation.swift
//  VirusTotal
//

import Foundation

enum FilePreparation {
    static func scanFileURL(for fileURL: URL) async throws -> URL {
        guard try needsZipArchive(for: fileURL) else {
            return fileURL
        }

        return try await makeZipArchive(for: fileURL)
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
        try await Task.detached(priority: .userInitiated) {
            let archiveDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("VirusTotalAppArchives", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: archiveDirectory, withIntermediateDirectories: true)

            let archiveURL = archiveDirectory
                .appendingPathComponent(appBundleURL.lastPathComponent)
                .appendingPathExtension("zip")

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

            try process.run()
            process.waitUntilExit()

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

            return archiveURL
        }.value
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

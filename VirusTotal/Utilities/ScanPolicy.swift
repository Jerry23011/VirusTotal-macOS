//
//  ScanPolicy.swift
//  VirusTotal
//

import Foundation
import UniformTypeIdentifiers

enum ScanPolicy {
    static let defaultUploadEndpoint = "https://www.virustotal.com/api/v3/files"
    static let largeUploadThreshold: Int64 = 33_554_432
    static let maxUploadSize: Int64 = 681_574_400
    static let maxPollingAttempts = 28
    static let activeDownloadExtensions: Set<String> = ["download", "crdownload", "part", "tmp", "aria2"]

    static func isSupportedFileSize(_ fileSize: Int64) -> Bool {
        fileSize > 0 && fileSize <= maxUploadSize
    }

    static func requiresLargeUploadEndpoint(fileSize: Int64) -> Bool {
        fileSize > largeUploadThreshold && isSupportedFileSize(fileSize)
    }

    static func uploadEndpoint(forFileSize fileSize: Int64, largeFileEndpoint: String? = nil) -> String {
        guard isSupportedFileSize(fileSize) else { return "" }
        guard fileSize > largeUploadThreshold else { return defaultUploadEndpoint }
        return largeFileEndpoint ?? defaultUploadEndpoint
    }

    static func shouldContinuePolling(attempt: Int) -> Bool {
        attempt < maxPollingAttempts
    }

    static func isValidAnalysisStats(_ stats: FileAnalysisStats) -> Bool {
        stats.allFlags.sum { $0 } > 0
    }

    static func isActiveDownloadExtension(_ pathExtension: String) -> Bool {
        activeDownloadExtensions.contains(pathExtension.lowercased())
    }

    static func category(forFilenameExtension pathExtension: String, isAppBundle: Bool = false) -> DownloadMonitorFileCategory {
        if isAppBundle { return .applications }

        guard let type = UTType(filenameExtension: pathExtension) else {
            return .other
        }

        return category(for: type)
    }

    static func category(for type: UTType) -> DownloadMonitorFileCategory {
        if type.conforms(to: .archive) { return .archives }
        if type.conforms(to: .image) { return .images }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .movie) { return .video }
        if type.conforms(to: .application) { return .applications }
        if type.conforms(to: .text) ||
            type.conforms(to: .pdf) ||
            type.conforms(to: .rtf) ||
            type.conforms(to: .html) ||
            type.conforms(to: .xml) ||
            type.conforms(to: .json) ||
            type.conforms(to: .sourceCode) ||
            type.conforms(to: .script) ||
            type.conforms(to: .propertyList) {
            return .documents
        }

        return .other
    }

    static func fileFingerprint(for url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            let modificationDate = (attributes[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
            return fileFingerprint(path: url.path, fileSize: size, modificationDate: modificationDate)
        } catch {
            return url.path
        }
    }

    static func fileFingerprint(path: String, fileSize: Int64, modificationDate: TimeInterval) -> String {
        "\(path)|\(fileSize)|\(modificationDate)"
    }
}

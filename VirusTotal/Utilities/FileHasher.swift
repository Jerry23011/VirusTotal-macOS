//
//  FileHasher.swift
//  VirusTotal
//

import CryptoKit
import Foundation

enum FileHasher {
    private static let chunkSize = 4 * 1024 * 1024

    static func sha256(for fileURL: URL) throws -> String {
        let fileHandle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? fileHandle.close()
        }

        var hasher = SHA256()
        while true {
            let data = try fileHandle.read(upToCount: chunkSize) ?? Data()
            guard !data.isEmpty else { break }
            hasher.update(data: data)
        }

        return hasher.finalize().compactMap { String(format: "%02x", $0) }.joined()
    }
}

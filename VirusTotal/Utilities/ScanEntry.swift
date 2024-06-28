//
//  ScanEntry.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-29.
//

import Foundation
import SwiftUI

// MARK: - ScanEntry

struct ScanEntry: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let target: String
    let scanType: ScanType
    let result: ScanResult

    init(scanType: ScanType, target: String, result: ScanResult) {
        self.id = UUID()
        self.timestamp = Date()
        self.target = target
        self.scanType = scanType
        self.result = result
    }
}

enum ScanType: LocalizedStringKey, Codable {
    case file
    case url
}

struct ScanResult: Codable {
    let malicious: Int
    let analysisDate: String
    let reputation: Int
}

// MARK: - ScanHistoryManager

@MainActor
@Observable
class ScanHistoryManager {
    static let shared = ScanHistoryManager()

    var scanEntries: [ScanEntry] = []

    private init() {}

    /// Constructs and returns the file URL where the scan history data will be saved
    private static func fileURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false)
            .appendingPathComponent("scanEntries.data")
    }

    /// Loads the scan history data from the file
    func load() async throws {
        let task = Task<[ScanEntry], Error> {
            let fileURL = try Self.fileURL()
            guard let data = try? Data(contentsOf: fileURL) else {
                return []
            }
            let entries = try JSONDecoder().decode([ScanEntry].self, from: data)
            return entries
        }
        let entries = try await task.value
        self.scanEntries = entries
    }

    /// Saves the provided array of `ScanEntry` objects to the file
    func save(entries: [ScanEntry]) async throws {
        let task = Task {
            let data = try JSONEncoder().encode(entries)
            let outfile = try Self.fileURL()
            try data.write(to: outfile)
        }
        _ = try await task.value
    }

    /// Given a `ScanEntry`, call `save()` to save it to `scanEntries`
    func addScanEntry(_ entry: ScanEntry) {
        scanEntries.insert(entry, at: 0)
        Task {
            do {
                try await save(entries: scanEntries)
            } catch {
                log.error("Error saving scan entries: \(error)")
            }
        }
    }
}

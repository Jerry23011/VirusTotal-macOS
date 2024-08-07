//
//  ViewModelExtensions.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-29.
//

import Foundation

extension FileViewModel {
    /// Creates and stores a new scan entry for a file scan
    func storeScanEntry() {
        guard statusMonitor == .success,
              let stats = lastAnalysisStats else { return }

        let result = ScanResult(
            malicious: stats.malicious,
            analysisDate: lastAnalysisDate ?? "n/a",
            reputation: reputation ?? -999
        )

        let entry = ScanEntry(scanType: .file, target: fileName ?? "n/a", result: result)
        Task { @MainActor in
            ScanHistoryManager.shared.addScanEntry(entry)
        }
    }
}

extension URLViewModel {
    /// Creates and stores a new scan entry for a URL scan
    func storeScanEntry() {
        guard statusMonitor == .success,
              let stats = analysisStats else { return }

        let result = ScanResult(
            malicious: stats.malicious,
            analysisDate: lastAnalysisTime,
            reputation: communityScore
        )

        let entry = ScanEntry(scanType: .url, target: inputURL, result: result)
        Task { @MainActor in
            ScanHistoryManager.shared.addScanEntry(entry)
        }
    }
}

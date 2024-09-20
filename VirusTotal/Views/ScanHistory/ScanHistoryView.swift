//
//  ScanHistoryView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-29.
//

import SwiftUI

struct ScanHistoryView: View {
    @State private var historyManager = ScanHistoryManager.shared
    @State private var tableSelection: Set<ScanEntry.ID> = []
    @State private var showingClearConfirmation = false

    var body: some View {
        Table(historyManager.scanEntries, selection: $tableSelection) {
            TableColumn("history.status") { entry in
                statusView(flag: entry.result.malicious)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .width(40)
            TableColumn("history.type") { entry in
                Text(entry.scanType.rawValue)
            }
            .width(40)
            TableColumn("history.target", value: \.target)
                .width(min: 40, ideal: 100)
            TableColumn("history.malicious") { entry in
                Text("\(entry.result.malicious)")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundStyle(entry.result.malicious != 0 ? .red : .primary)
            }
            .width(54)
            TableColumn("history.analysis.date", value: \.result.analysisDate)
                .width(79)
            TableColumn("history.community.score") { entry in
                Text("\(entry.result.reputation)")
                    .foregroundStyle(entry.result.reputation < 0 ? .orange : .primary)
            }
            .width(min: 80, ideal: 80)
        }
        .task {
            do {
                try await historyManager.load()
            } catch {
                log.error("Error loading scan entries: \(error)")
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                if !historyManager.scanEntries.isEmpty {
                    Button(action: showConfirmClear) {
                        Label("history.toolbar.clear", systemImage: "trash")
                    }
                    .help("history.toolbar.clear.help")
                    .keyboardShortcut(.delete, modifiers: [.command, .shift])
                    .confirmationDialog("history.clear.confirmation.title",
                                        isPresented: $showingClearConfirmation) {
                        Button("history.clear.confirmation.clear",
                               role: nil,
                               action: clearHistory)
                        Button("history.clear.confirmation.cancel",
                               role: .cancel) { }
                    } message: {
                       Text("history.clear.confirmation.message")
                    }
                }
            }
        }
    }

    // MARK: Private

    /// Clears the ScanEntries
    private func clearHistory() {
        historyManager.scanEntries.removeAll()
        Task {
            do {
                try await historyManager.save(entries: [])
            } catch {
                log.error("Error clearing scan history: \(error)")
            }
        }
    }

    /// Changes `showingClearConfirmation` to true
    private func showConfirmClear() {
        showingClearConfirmation = true
    }

    @ViewBuilder
    private func statusView(flag: Int) -> some View {
        switch flag {
        case 0:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .symbolRenderingMode(.monochrome)
        default:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.red)
                .symbolRenderingMode(.multicolor)
        }
    }
}

#Preview {
    ScanHistoryView()
        .frame(minWidth: 600, minHeight: 500)
}

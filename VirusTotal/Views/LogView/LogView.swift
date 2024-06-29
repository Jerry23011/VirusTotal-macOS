//
//  LogView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI

@MainActor
struct LogView: View {
    @State private var logManager = LogManager.shared

    var body: some View {
        if !logManager.logs.isEmpty {
            logDisplay
        } else {
            LogEmptyView()
        }
    }

    // MARK: ViewBuilder
    private var logDisplay: some View {
        ScrollViewReader { scrollViewProxy in
            List {
                ForEach(logManager.logs) { logEntry in
                    VStack(alignment: .leading) {
                        Text(logEntry.message)
                            .font(.body)
                        Text(dateFormatter.string(from: logEntry.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .id(logEntry.id)
                    .itemProvider {
                        NSItemProvider(object: logEntry.message as NSString)
                    }
                }
            }
            .listStyle(.plain)
            .onChange(of: logManager.logs) {
                if let lastLog = logManager.logs.last {
                    scrollViewProxy.scrollTo(lastLog.id, anchor: .bottom)
                }
            }
            .toolbar {
                ToolbarItem {
                    if !logManager.logs.isEmpty {
                        Button(action: clearLogs) {
                            Image(systemName: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: Private
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }

    /// Remove all the logs in logManager.logs
    private func clearLogs() {
        logManager.removeAll()
    }
}

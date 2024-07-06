//
//  LogEntry.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import Foundation
import SwiftyBeaver

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String

    init(message: String) {
        self.timestamp = Date()
        self.message = message
    }
}

@MainActor
@Observable
final class LogManager {
    private(set) var logs: [LogEntry] = []

    static let shared = LogManager()

    private init() {}

    func addLog(_ message: String) {
        let newEntry = LogEntry(message: message)
        logs.append(newEntry)

        // Keep only the last 1000 log entries to prevent memory issues
        if logs.count > 1000 {
            logs.removeFirst(logs.count - 1000)
        }
    }

    func removeAll() {
        logs.removeAll()
    }
}

final class LogViewDestination: BaseDestination {

    override init() {
        super.init()
        levelColor.verbose = "🟣 "
        levelColor.debug = "🟢 "
        levelColor.info = "🔵 "
        levelColor.warning = "🟡 "
        levelColor.error = "🔴 "
        levelColor.critical = "🔴 "
        levelColor.fault = "🔴 "
    }

    override func send(_ level: SwiftyBeaver.Level,
                       msg: String,
                       thread: String,
                       file: String,
                       function: String,
                       line: Int,
                       context: Any? = nil) -> String? {
        let formattedString = super.send(level,
                                         msg: msg,
                                         thread: thread,
                                         file: file,
                                         function: function,
                                         line: line,
                                         context: context)
        if let logMessage = formattedString {
            Task { @MainActor in
                LogManager.shared.addLog(logMessage)
            }
        }
        return formattedString
    }
}

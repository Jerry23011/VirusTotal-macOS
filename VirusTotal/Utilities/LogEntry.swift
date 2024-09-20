//
//  LogEntry.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import Foundation
import SwiftyBeaver

/// Set global logging
let log = SwiftyBeaver.self

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

    /// Configure global logging with SwiftyBeaver
    static func configureLogging() {
        // Add console destination
        let console = ConsoleDestination()
        console.logPrintWay = .logger(subsystem: "org.eu.moyuapp.VirusTotal",
                                      category: "VirusTotal")
        console.asynchronously = true
        log.addDestination(console)

        // Add LogView() destination
        let logView = LogViewDestination()
        logView.asynchronously = true
        log.addDestination(logView)

        // Add file destination
        let file = FileDestination()
        let logFileName = "VirusTotal.log"
        let fileManager = FileManager.default
        if let logsDirectory = fileManager.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first?.appendingPathComponent("Logs") {
            do {
                // Ensure the Logs directory exists
                try fileManager.createDirectory(
                    at: logsDirectory,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                let logFileURL = logsDirectory.appendingPathComponent(logFileName)
                file.logFileURL = logFileURL
                file.format = "$Dyyyy-MM-dd HH:mm:ss.SSS$d $C$L$c $N.$F:$l - $M"
                file.asynchronously = true
                log.addDestination(file)
                log.verbose("App Launched")
            } catch {
                log.error("Failed to create Logs directory: \(error)")
            }
        } else {
            log.error("Failed to set log file URL.")
        }
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

//
//  LogEntry.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import Foundation
import OSLog

/// Set global logging
let log = AppLogger.shared

struct LogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let message: String

    init(timestamp: Date, message: String) {
        self.timestamp = timestamp
        self.message = message
    }
}

private enum LogLevel: String {
    case verbose = "VERBOSE"
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
    case fault = "FAULT"

    var consolePrefix: String {
        switch self {
        case .verbose:
            "💜 "
        case .debug:
            "💚 "
        case .info:
            "💙 "
        case .warning:
            "💛 "
        case .error, .critical, .fault:
            "❤️ "
        }
    }

    var logViewPrefix: String {
        switch self {
        case .verbose:
            "🟣 "
        case .debug:
            "🟢 "
        case .info:
            "🔵 "
        case .warning:
            "🟡 "
        case .error, .critical, .fault:
            "🔴 "
        }
    }
}

final class AppLogger: @unchecked Sendable {
    static let shared = AppLogger()

    private let subsystem = "org.eu.moyuapp.VirusTotal"
    private let category = "VirusTotal"
    private let queue = DispatchQueue(label: "org.eu.moyuapp.VirusTotal.logging",
                                      qos: .utility)
    private let fileManager = FileManager.default
    private let consoleLogger: Logger
    private let logFileName = "VirusTotal.log"
    private let consoleDateFormatter: DateFormatter
    private let logViewDateFormatter: DateFormatter
    private let fileDateFormatter: DateFormatter
    private let logFileURL: URL?
    private var fileHandle: FileHandle?
    private var hasReportedFileSinkFailure = false

    private init() {
        consoleLogger = Logger(subsystem: subsystem, category: category)
        consoleDateFormatter = Self.makeLogFormatter(format: "HH:mm:ss.SSS")
        logViewDateFormatter = Self.makeLogFormatter(format: "HH:mm:ss.SSS")
        fileDateFormatter = Self.makeLogFormatter(format: "yyyy-MM-dd HH:mm:ss.SSS")

        do {
            logFileURL = try Self.makeLogFileURL(fileManager: fileManager,
                                                 logFileName: logFileName)
        } catch {
            logFileURL = nil
            consoleLogger.error("Failed to configure file logging: \(error.localizedDescription, privacy: .public)")
        }
    }

    func verbose(_ message: @autoclosure () -> Any,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
        write(level: .verbose,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    func debug(_ message: @autoclosure () -> Any,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        write(level: .debug,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    func info(_ message: @autoclosure () -> Any,
              file: String = #file,
              function: String = #function,
              line: Int = #line) {
        write(level: .info,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    func warning(_ message: @autoclosure () -> Any,
                 file: String = #file,
                 function: String = #function,
                 line: Int = #line) {
        write(level: .warning,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    func error(_ message: @autoclosure () -> Any,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        write(level: .error,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    func critical(_ message: @autoclosure () -> Any,
                  file: String = #file,
                  function: String = #function,
                  line: Int = #line) {
        write(level: .critical,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    func fault(_ message: @autoclosure () -> Any,
               file: String = #file,
               function: String = #function,
               line: Int = #line) {
        write(level: .fault,
              message: String(describing: message()),
              file: file,
              function: function,
              line: line)
    }

    private func write(level: LogLevel,
                       message: String,
                       file: String,
                       function: String,
                       line: Int) {
        let timestamp = Date()
        let strippedFunction = stripParams(function)
        let fileName = fileNameWithoutSuffix(file)

        queue.async { [self] in
            let consoleMessage = formattedMessage(timestamp: timestamp,
                                                 formatter: consoleDateFormatter,
                                                 prefix: level.consolePrefix,
                                                 level: level,
                                                 fileName: fileName,
                                                 function: strippedFunction,
                                                 line: line,
                                                 message: message)
            writeToConsole(consoleLogger,
                                message: consoleMessage,
                                level: level)

            let logViewMessage = formattedMessage(timestamp: timestamp,
                                                 formatter: logViewDateFormatter,
                                                 prefix: level.logViewPrefix,
                                                 level: level,
                                                 fileName: fileName,
                                                 function: strippedFunction,
                                                 line: line,
                                                 message: message)
            Task { @MainActor in
                LogManager.shared.addLog(logViewMessage, timestamp: timestamp)
            }

            let fileMessage = formattedMessage(timestamp: timestamp,
                                              formatter: fileDateFormatter,
                                              prefix: "",
                                              level: level,
                                              fileName: fileName,
                                              function: strippedFunction,
                                              line: line,
                                              message: message)
            writeToFile(fileMessage)
        }
    }

    // swiftlint:disable function_parameter_count

    private func formattedMessage(timestamp: Date,
                                  formatter: DateFormatter,
                                  prefix: String,
                                  level: LogLevel,
                                  fileName: String,
                                  function: String,
                                  line: Int,
                                  message: String) -> String {
        let formattedTimestamp = formatter.string(from: timestamp)
        return "\(formattedTimestamp) \(prefix)\(level.rawValue) \(fileName).\(function):\(line) - \(message)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // swiftlint:enable function_parameter_count

    private func writeToConsole(_ logger: Logger,
                                message: String,
                                level: LogLevel) {
        switch level {
        case .verbose:
            logger.trace("\(message, privacy: .public)")
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        case .critical:
            logger.critical("\(message, privacy: .public)")
        case .fault:
            logger.fault("\(message, privacy: .public)")
        }
    }

    private func writeToFile(_ message: String) {
        guard let logFileURL = logFileURL else { return }

        do {
            let handle = try fileHandle(for: logFileURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: Data((message + "\n").utf8))
            hasReportedFileSinkFailure = false
        } catch {
            closeFileHandle()
            reportFileSinkFailure(error, url: logFileURL)
        }
    }

    private func fileHandle(for url: URL) throws -> FileHandle {
        if let fileHandle {
            return fileHandle
        }

        if !fileManager.fileExists(atPath: url.path) {
            _ = fileManager.createFile(atPath: url.path, contents: nil)
        }

        let fileHandle = try FileHandle(forWritingTo: url)
        self.fileHandle = fileHandle
        return fileHandle
    }

    private func closeFileHandle() {
        try? fileHandle?.close()
        fileHandle = nil
    }

    private func reportFileSinkFailure(_ error: Error, url: URL) {
        guard !hasReportedFileSinkFailure else { return }

        hasReportedFileSinkFailure = true
        consoleLogger.error("Failed to write log file \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
    }

    private func stripParams(_ function: String) -> String {
        guard let braceIndex = function.firstIndex(of: "(") else {
            return function
        }

        return "\(function[..<braceIndex])()"
    }

    private func fileNameWithoutSuffix(_ file: String) -> String {
        URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
    }

    private static func makeLogFileURL(fileManager: FileManager,
                                       logFileName: String) throws -> URL {
        guard let logsDirectory = fileManager.urls(for: .libraryDirectory,
                                                   in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true) else {
            throw CocoaError(.fileNoSuchFile)
        }

        try fileManager.createDirectory(at: logsDirectory,
                                        withIntermediateDirectories: true)
        return logsDirectory.appendingPathComponent(logFileName)
    }

    private static func makeLogFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}

@MainActor
@Observable
final class LogManager {
    private(set) var logs: [LogEntry] = []

    static let shared = LogManager()

    private init() {}

    func addLog(_ message: String, timestamp: Date) {
        let newEntry = LogEntry(timestamp: timestamp, message: message)
        logs.append(newEntry)

        // Keep only the last 1000 log entries to prevent memory issues
        if logs.count > 1000 {
            logs.removeFirst(logs.count - 1000)
        }
    }

    func removeAll() {
        logs.removeAll()
    }

    /// Configure global logging.
    static func configureLogging() {
        log.verbose("App Launched")
    }
}

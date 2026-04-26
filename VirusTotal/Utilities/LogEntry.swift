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

    init(message: String) {
        self.timestamp = Date()
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

    private init() {
        consoleLogger = Logger(subsystem: subsystem, category: category)
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
        let strippedFunction = stripParams(function)
        let fileName = fileNameWithoutSuffix(file)

        queue.async { [consoleLogger, weak self] in
            guard let self else { return }

            let consoleMessage = self.formattedMessage(timestampFormat: "HH:mm:ss.SSS",
                                                       prefix: level.consolePrefix,
                                                       level: level,
                                                       fileName: fileName,
                                                       function: strippedFunction,
                                                       line: line,
                                                       message: message)
            self.writeToConsole(consoleLogger,
                                message: consoleMessage,
                                level: level)

            let logViewMessage = self.formattedMessage(timestampFormat: "HH:mm:ss.SSS",
                                                       prefix: level.logViewPrefix,
                                                       level: level,
                                                       fileName: fileName,
                                                       function: strippedFunction,
                                                       line: line,
                                                       message: message)
            Task { @MainActor in
                LogManager.shared.addLog(logViewMessage)
            }

            let fileMessage = self.formattedMessage(timestampFormat: "yyyy-MM-dd HH:mm:ss.SSS",
                                                    prefix: "",
                                                    level: level,
                                                    fileName: fileName,
                                                    function: strippedFunction,
                                                    line: line,
                                                    message: message)
            self.writeToFile(fileMessage)
        }
    }

    // swiftlint:disable function_parameter_count

    private func formattedMessage(timestampFormat: String,
                                  prefix: String,
                                  level: LogLevel,
                                  fileName: String,
                                  function: String,
                                  line: Int,
                                  message: String) -> String {
        let timestamp = DateFormatter.logFormatter(format: timestampFormat).string(from: Date())
        return "\(timestamp) \(prefix)\(level.rawValue) \(fileName).\(function):\(line) - \(message)"
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
            if !fileManager.fileExists(atPath: logFileURL.path) {
                _ = fileManager.createFile(atPath: logFileURL.path, contents: nil)
            }

            let fileHandle = try FileHandle(forWritingTo: logFileURL)
            defer { try? fileHandle.close() }

            try fileHandle.seekToEnd()
            let data = Data((message + "\n").utf8)
            try fileHandle.write(contentsOf: data)
        } catch {
            print("VirusTotal logger could not write to file \(logFileURL).")
        }
    }

    private var logFileURL: URL? {
        guard let logsDirectory = fileManager.urls(for: .libraryDirectory,
                                                   in: .userDomainMask)
            .first?
            .appendingPathComponent("Logs", isDirectory: true) else {
            return nil
        }

        do {
            try fileManager.createDirectory(at: logsDirectory,
                                            withIntermediateDirectories: true)
        } catch {
            return nil
        }

        return logsDirectory.appendingPathComponent(logFileName)
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

    /// Configure global logging.
    static func configureLogging() {
        log.verbose("App Launched")
    }
}

private extension DateFormatter {
    static func logFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter
    }
}

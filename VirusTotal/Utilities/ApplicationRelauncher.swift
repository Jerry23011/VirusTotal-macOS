//
//  ApplicationRelauncher.swift
//  VirusTotal
//

import AppKit
import Defaults
import Foundation

enum ApplicationRelauncher {
    static func restart() {
        Defaults[.showMainWindowOnNextLaunch] = true
        UserDefaults.standard.synchronize()

        let process = Process()
        process.executableURL = URL(filePath: "/bin/sh")
        process.arguments = [
            "-c",
            "sleep 0.5; /usr/bin/open -n \(shellQuote(Bundle.main.bundleURL.path))"
        ]

        do {
            try process.run()
            Task { @MainActor in
                NSApp.terminate(nil)
            }
        } catch {
            log.error("Failed to restart application: \(error)")
        }
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

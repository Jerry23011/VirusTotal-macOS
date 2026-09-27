//
//  AppRelauncher.swift
//  VirusTotal
//

import AppKit
import Defaults

enum AppRelauncher {
    @MainActor
    static func restart() {
        Defaults[.showMainWindowOnNextLaunch] = true
        UserDefaults.standard.synchronize()

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true

        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            Task { @MainActor in
                if let error {
                    Defaults[.showMainWindowOnNextLaunch] = false
                    UserDefaults.standard.synchronize()
                    log.error("Failed to restart application: \(error)")
                } else {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}

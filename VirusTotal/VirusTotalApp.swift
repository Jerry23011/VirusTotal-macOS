//
//  VirusTotalApp.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults
import TipKit
import Sparkle
import SwiftyBeaver

@main
struct VirusTotalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Default(.appFirstLaunch) private var appFirstLaunch: Bool
    @ObservedObject private var appState = AppState.shared

    var body: some Scene {
        Window("VirusTotal for macOS", id: WindowID.main.rawValue) {
            ContentView()
                .sheet(isPresented: $appFirstLaunch, onDismiss: {
                    appFirstLaunch = false
                }, content: {
                    LaunchView()
                        .frame(width: 400, height: 430)
                })
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 550)
        .defaultPosition(.center)

        Window("About VirusTotal", id: WindowID.about.rawValue) {
            AboutView()
        }
        .defaultSize(width: 530, height: 220)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(updater: updaterController.updater)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                openMainWindow
            }
            CommandGroup(replacing: .appInfo) {
                openAboutWindow
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(before: .textEditing) {
                openSidebarSearch
            }
        }
    }

    // MARK: Menubar Items
    @ViewBuilder
    var openMainWindow: some View {
        Button {openWindow(id: "main")} label: {
            Text("menubar.open.main")
        }
        .keyboardShortcut("n", modifiers: .command)
    }

    @ViewBuilder
    var openAboutWindow: some View {
        Button {openWindow(id: "about")} label: {
            Text("menubar.open.about")
        }
    }

    @ViewBuilder
    var openSidebarSearch: some View {
        Button {appState.sidebarSearchFocused = true} label: {
            Text("menubar.edit.search")
        }
        .keyboardShortcut("f")
    }

    // MARK: Internal
    init() {
        // Tips
        #if DEBUG
        try? Tips.resetDatastore()
        #endif
        try? Tips.configure()
        // Updater
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil)
        // Logging
        configureLogging()
    }

    // MARK: Private
    private let updaterController: SPUStandardUpdaterController

    /// Configure logging with SwiftyBeaver
    private func configureLogging() {
            // Add console destination
            let console = ConsoleDestination()
            log.addDestination(console)

            // Add file destination
            let file = FileDestination()
            let logFileName = "VirusTotal.log"
            let fileManager = FileManager.default
            if let logsDirectory = fileManager.urls(
                for: .cachesDirectory,
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
                    log.addDestination(file)
                    log.info("App Launched")
                } catch {
                    log.error("Failed to create Logs directory: \(error)")
                }
            } else {
                log.error("Failed to set log file URL.")
            }
        }
}

let log = SwiftyBeaver.self

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
    @Environment(\.openURL) private var openURL
    @Default(.appFirstLaunch) private var appFirstLaunch: Bool
    private var appState = AppState.shared

    var body: some Scene {
        Window("VirusTotal for macOS", id: WindowID.main.rawValue) {
            if !miniMode {
                ContentView()
                    .sheet(isPresented: $appFirstLaunch, onDismiss: {
                        appFirstLaunch = false
                    }, content: {
                        LaunchView()
                            .frame(width: 400, height: 430)
                    })
            } else {
                MiniModeView()
                    .frame(width: 245, height: 180)
            }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 550)
        .defaultPosition(.center)
        .commandsRemoved()

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
            CommandGroup(replacing: .appInfo) {
                openAboutWindow
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
            CommandGroup(replacing: .newItem) {
                openMainWindow
            }
            CommandGroup(before: .help) {
                provideFeedback
                openLogDirectory
                Divider()
            }
            CommandGroup(before: .textEditing) {
                openSidebarSearch
            }
            CommandMenu("menubar.go.title") {
                menubarGo
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

    @ViewBuilder
    var openLogDirectory: some View {
        Button {
            logDirectory.openInFinder()
        } label: {
            Text("menubar.check.log")
        }
    }

    @ViewBuilder
    var provideFeedback: some View {
        Button {
            openURL(feedbackURL)
        } label: {
            Text("menubar.help.feedback")
        }
    }

    @ViewBuilder
    var menubarGo: some View {
        Button {
            appState.selectedSidebarItem = .home
        } label: {
            Text("menubar.go.home")
        }
        .keyboardShortcut("1")
        .disabled(miniMode)

        Button {
            appState.selectedSidebarItem = .fileUpload
        } label: {
            Text("menubar.go.file")
        }
        .keyboardShortcut("2")
        .disabled(miniMode)

        Button {
            appState.selectedSidebarItem = .urlLookup
        } label: {
            Text("menubar.go.url")
        }
        .keyboardShortcut("3")
        .disabled(miniMode)
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
    private let feedbackURL = URL(string: "https://github.com/Jerry23011/VirusTotal-macOS/issues/new/choose")!
    private var miniMode: Bool { Defaults[.miniMode] }
    private var logDirectory: URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent("Library/Caches/Logs", isDirectory: true)
    }

    /// Configure logging with SwiftyBeaver
    private func configureLogging() {
        // Add console destination
        let console = ConsoleDestination()
        console.logPrintWay = .logger(subsystem: "org.eu.moyuapp.VirusTotal",
                                      category: "VirusTotal")
        log.addDestination(console)

        // Add LogView() destination
        log.addDestination(LogViewDestination())

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
                log.verbose("App Launched")
            } catch {
                log.error("Failed to create Logs directory: \(error)")
            }
        } else {
            log.error("Failed to set log file URL.")
        }
    }
}

let log = SwiftyBeaver.self

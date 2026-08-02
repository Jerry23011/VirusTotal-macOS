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

@main
struct VirusTotalApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.openURL) private var openURL
    @Default(.appFirstLaunch) private var appFirstLaunch: Bool
    @Default(.appLanguage) private var appLanguage: AppLanguage
    @State private var miniMode = Defaults[.miniMode]
    @State private var shouldShowFullMainWindowAfterRelaunch = Defaults[.showMainWindowOnNextLaunch]
    @State private var scanHistoryManager = ScanHistoryManager.shared
    @State private var downloadsMonitor = DownloadsMonitorViewModel.shared
    @State private var didStartBackgroundServices = false
    private var appState = AppState.shared

    var body: some Scene {
        Window("VirusTotal for macOS", id: WindowID.main.rawValue) {
            mainWindowContent
                .environment(\.locale, appLocale)
                .task(priority: .background) {
                    appDelegate.openMainWindowAction = {
                        openWindow(id: WindowID.main.rawValue)
                    }
                    await startBackgroundServicesIfNeeded()
                }
                .onReceive(NotificationCenter.default.publisher(for: .openMainWindowRequested)) { _ in
                    openWindow(id: WindowID.main.rawValue)
                }
                .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
                    openSettings()
                }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 808, height: 639)
        .defaultPosition(.center)
        .commandsRemoved()

        Window("About VirusTotal", id: WindowID.about.rawValue) {
            AboutView()
                .environment(\.locale, appLocale)
        }
        .defaultSize(width: 530, height: 220)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsView(updater: updaterController.updater)
                .environment(\.locale, appLocale)
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

    @ViewBuilder
    private var mainWindowContent: some View {
        if shouldUseMiniMode {
            MiniModeView()
                .frame(width: 290, height: 180)
        } else {
            ContentView()
                .sheet(isPresented: $appFirstLaunch, onDismiss: {
                    appFirstLaunch = false
                }, content: {
                    LaunchView()
                        .frame(width: 400, height: 430)
                })
        }
    }

    private var shouldUseMiniMode: Bool {
        miniMode && !shouldShowFullMainWindowAfterRelaunch
    }

    private var appLocale: Locale {
        appLanguage.locale
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
        .disabled(shouldUseMiniMode)

        Button {
            appState.selectedSidebarItem = .fileUpload
        } label: {
            Text("menubar.go.file")
        }
        .keyboardShortcut("2")
        .disabled(shouldUseMiniMode)

        Button {
            appState.selectedSidebarItem = .urlLookup
        } label: {
            Text("menubar.go.url")
        }
        .keyboardShortcut("3")
        .disabled(shouldUseMiniMode)

        Button {
            appState.selectedSidebarItem = .fileBatch
        } label: {
            Text("menubar.go.fileBatch")
        }
        .keyboardShortcut("4")
        .disabled(shouldUseMiniMode)
    }

    private func startBackgroundServicesIfNeeded() async {
        guard !didStartBackgroundServices else { return }
        didStartBackgroundServices = true

        do {
            try await scanHistoryManager.load()
        } catch {
            log.error("Error loading scan entries: \(error)")
        }
        await NotificationManager.requestAuthorization()
        downloadsMonitor.startIfNeeded()
    }

    // MARK: Internal
    init() {
        Self.resetMainWindowAutosavedLayout()
        AppLanguage.synchronizePreference()
        APIKeychain.migrateAPIKeyFromDefaultsIfNeeded()
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
        LogManager.configureLogging()
    }

    // MARK: Private
    private let updaterController: SPUStandardUpdaterController
    private let feedbackURL = AppLinks.feedback

    private var logDirectory: URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent("Library/Logs", isDirectory: true)
    }

    private static func resetMainWindowAutosavedLayout() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "NSWindow Frame main")
        defaults.removeObject(forKey: "NSSplitView Subview Frames main, SidebarNavigationSplitView")
    }
}

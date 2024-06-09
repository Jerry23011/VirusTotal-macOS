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
    @Default(.appFirstLaunch) private var appFirstLaunch: Bool

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
    }

    // MARK: Private
    private let updaterController: SPUStandardUpdaterController
}

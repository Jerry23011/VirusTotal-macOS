//
//  SettingsView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    private let updater: SPUUpdater

    var body: some View {
        TabView {
            GeneralTab(updater: updater)
                .tabItem {
                    Label("settings.general", systemImage: "gear")
                }

            APITab()
                .tabItem {
                    Label("settings.api", systemImage: "key")
                }

            AdvancedTab()
                .tabItem {
                    Label("settings.advanced", systemImage: "gearshape.2")
                }
        }
        .frame(width: 500, height: 400)
    }

    // MARK: Internal
    init(updater: SPUUpdater) {
        self.updater = updater
    }

}

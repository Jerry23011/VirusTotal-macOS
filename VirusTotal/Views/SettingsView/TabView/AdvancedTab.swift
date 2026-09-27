//
//  AdvancedTab.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults

struct AdvancedTab: View {
    @State private var miniMode = Defaults[.miniMode]
    @State private var showRestartAlert = false

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $miniMode) {
                    SettingsViewItem(color: .accentColor,
                                     systemImage: "smallcircle.filled.circle",
                                     labelText: "settings.advanced.mini",
                                     subtitleText: "settings.advanced.mini.restart")
                }
                .padding(.vertical, 4)
                .onChange(of: miniMode) {
                    showRestartAlert = true
                }
            }
        }
        .controlSize(.small)
        .formStyle(.grouped)
        .scrollDisabled(true)
        .alert("settings.restart.alert.title", isPresented: $showRestartAlert) {
            Button("settings.restart.alert.confirm") {
                saveMiniModePreference()
                AppRelauncher.restart()
            }
            Button("settings.restart.alert.later", role: .cancel) {
                saveMiniModePreference()
            }
        } message: {
            Text("settings.advanced.mini.restart.message")
        }
    }

    // MARK: Private

    /// Written only once the alert is answered, so the window does not switch
    /// to Mini Mode underneath the settings sheet.
    private func saveMiniModePreference() {
        Defaults[.miniMode] = miniMode
    }
}

#Preview {
    AdvancedTab()
        .frame(width: 500, height: 400)
}

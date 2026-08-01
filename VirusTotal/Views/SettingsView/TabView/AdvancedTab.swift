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
    @Default(.backgroundMonitoringMode) private var backgroundMonitoringMode: Bool

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

                Toggle(isOn: $backgroundMonitoringMode) {
                    SettingsViewItem(
                        color: .orange,
                        systemImage: "menubar.rectangle",
                        labelText: "Background Monitoring",
                        subtitleText: "Keeps Downloads Monitor running without a Dock icon")
                }
                .onChange(of: backgroundMonitoringMode) {
                    NotificationCenter.default.post(name: .backgroundMonitoringModeChanged, object: nil)
                }
            }
        }
        .controlSize(.small)
        .formStyle(.grouped)
        .scrollDisabled(true)
        .alert("Restart required", isPresented: $showRestartAlert) {
            Button("Restart") {
                saveMiniModePreference()
                ApplicationRelauncher.restart()
            }
            Button("Later", role: .cancel) {
                saveMiniModePreference()
            }
        } message: {
            Text("Restart VirusTotal to apply Mini Mode changes.")
        }
    }

    private func saveMiniModePreference() {
        Defaults[.miniMode] = miniMode
        UserDefaults.standard.synchronize()
    }

}

#Preview {
    AdvancedTab()
        .frame(width: 500, height: 400)
}

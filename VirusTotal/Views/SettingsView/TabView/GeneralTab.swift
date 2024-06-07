//
//  GeneralTab.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import LaunchAtLogin
import Defaults
import Sparkle

struct GeneralTab: View {
    private let updater: SPUUpdater

    @State private var autoChecksForUpdates: Bool
    @Default(.cleanURL) private var cleanURL: Bool

    var body: some View {
        Form {

            Section {
                Toggle(isOn: $cleanURL) {
                    SettingsViewItem(
                        color: .blue,
                        systemImage: "hand.raised.fill",
                        labelText: "settings.general.cleanurl"
                    )
                }
            }

            Section {
                LabeledContent {
                    Button("settings.general.check_now") {
                        updater.checkForUpdates()
                    }
                } label: {
                    SettingsViewItem(color: .purple,
                                     systemImage: "arrow.triangle.2.circlepath",
                                     labelText: "settings.general.check_for_updates",
                                     subtitleText: "settnigs.general.current_version \(currentVersion)")
                }
                .controlSize(.regular)
                .padding(.vertical, 4)
                Toggle(isOn: $autoChecksForUpdates) {
                    SettingsViewItem(color: .purple,
                                     systemImage: "gearshape.arrow.triangle.2.circlepath",
                                     labelText: "settings.general.update"
                    )
                }
                .onChange(of: autoChecksForUpdates) {_, newValue in
                    updater.automaticallyChecksForUpdates = newValue
                }
                LaunchAtLogin.Toggle {
                    SettingsViewItem(
                        color: .orange,
                        systemImage: "paperplane.fill",
                        labelText: "settings.general.launch")
                }
            }
        }
        .controlSize(.small)
        .formStyle(.grouped)
        .scrollDisabled(true)
    }

    // MARK: Internal
    init(updater: SPUUpdater) {
        self.updater = updater
        self.autoChecksForUpdates = updater.automaticallyChecksForUpdates
    }

    // MARK: Private
    private var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
    }
}

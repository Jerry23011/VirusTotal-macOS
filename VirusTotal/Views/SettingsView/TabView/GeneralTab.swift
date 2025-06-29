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
    @Default(.startPage) private var startPage: NavigationItem
    @Default(.enableNotification) private var enableNotification: Bool

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
                Toggle(isOn: $enableNotification) {
                    SettingsViewItem(
                        color: .blue,
                        systemImage: getNotificationIcon(),
                        labelText: "settings.general.notification"
                    )
                }
                Picker(selection: $startPage) {
                    ForEach(NavigationItem.allCases) { item in
                        Text(item.rawValue.nslocalized)
                    }
                } label: {
                    SettingsViewItem(color: .blue,
                                     systemImage: defaultServiceIcon(),
                                     labelText: "settings.general.startpage")
                }
                .controlSize(.regular)
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

    /// Observe`startPage` to return a SFSymbol based on the chosen page
    private func defaultServiceIcon() -> String {
        switch startPage {
        case .home:
            return "house.fill"
        case .file:
            return "arrow.up.doc.fill"
        case .url:
            return "link"
        case .fileBatch:
            return "arrow.up.page.on.clipboard"
        }
    }

    /// Returns "bell.badge.fill" if enableNotification is true, returns "bell.slash.fill" otherwise
    private func getNotificationIcon() -> String {
        return enableNotification ? "bell.badge.fill" : "bell.slash.fill"
    }
}

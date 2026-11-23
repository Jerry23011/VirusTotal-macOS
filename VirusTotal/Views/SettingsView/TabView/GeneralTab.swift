//
//  GeneralTab.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import AppKit
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

                HStack(alignment: .center) {
                    SettingsViewItem(
                        color: .blue,
                        systemImage: "globe",
                        labelText: "settings.general.language"
                    )
                    Spacer()
                    Button(action: openLanguageSettings) {
                        HStack(spacing: 6) {
                            Text(verbatim: currentLanguageName)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, 3)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text("settings.general.language.open"))
                    .accessibilityValue(Text(verbatim: currentLanguageName))
                    .help("settings.general.language.hint")
                    .accessibilityHint(Text("settings.general.language.hint"))
                }
                .controlSize(.regular)
                .font(.body)
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
    }

    // MARK: Internal
    init(updater: SPUUpdater) {
        self.updater = updater
        self.autoChecksForUpdates = updater.automaticallyChecksForUpdates
    }

    // MARK: Private
    private var currentLanguageName: String {
        let bundle = Bundle.main
        let identifier = bundle.preferredLocalizations.first ?? bundle.developmentLocalization ?? "en"
        let locale = Locale(identifier: identifier)
        let name = locale.localizedString(forIdentifier: identifier) ?? identifier
        return name.prefix(1).uppercased(with: locale) + name.dropFirst()
    }

    private func openLanguageSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }

        if let settings = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.systempreferences") {
            NSWorkspace.shared.open(settings)
        }
    }

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

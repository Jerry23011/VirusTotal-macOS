//
//  AdvancedTab.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults

struct AdvancedTab: View {
    @Default(.miniMode) private var miniMode: Bool

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $miniMode) {
                    SettingsViewItem(color: .accentColor,
                                     systemImage: "smallcircle.filled.circle",
                                     labelText: "settings.advanced.mini",
                                     subtitleText: "settings.coming.soon")
                }
                .padding(.vertical, 3)
                .disabled(true)
            }
        }
        .controlSize(.small)
        .formStyle(.grouped)
        .scrollDisabled(true)
    }
}

#Preview {
    AdvancedTab()
        .frame(width: 500, height: 400)
}

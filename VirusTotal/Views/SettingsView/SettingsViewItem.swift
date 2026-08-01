//
//  SettingsViewItem.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//

import SwiftUI

struct SettingsViewItem: View {
    let color: Color
    let systemImage: String
    let labelText: LocalizedStringKey
    var subtitleText: LocalizedStringKey?

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: 20, alignment: .center)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(alignment: .center) {
                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(labelText)
                    .lineLimit(1)
                if let subtitleText {
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
    }
}

#Preview {
    SettingsViewItem(color: .accentColor,
                     systemImage: "swift",
                     labelText: "settings.advanced.mini",
                     subtitleText: "settings.advanced.mini.restart")
}

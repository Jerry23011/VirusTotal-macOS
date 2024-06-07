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
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                )
            VStack(alignment: .leading) {
                Text(labelText)
                if let subtitleText {
                    Text(subtitleText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 20)
        }
    }
}

#Preview {
    SettingsViewItem(color: .accentColor,
                     systemImage: "swift",
                     labelText: "settings.coming.soon",
                     subtitleText: "settings.coming.soon")
}

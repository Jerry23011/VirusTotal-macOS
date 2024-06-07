//
//  OpenFinderButton.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import SwiftUI

struct OpenFinderButton: View {
    let title: LocalizedStringKey
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action, label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.secondary)
                    .font(.system(size: 20))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            }
        })
        .buttonStyle(OpenFinderButtonStyle())
    }

    private struct OpenFinderButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .contentShape(Rectangle())
                .padding(7)
                .frame(height: 36)
                .background(Color(.labelColor).opacity(configuration.isPressed ? 0.1 : 0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    OpenFinderButton(title: "fileview.button.open.finder", systemImage: "folder", action: {})
        .frame(width: 200, height: 36)
}

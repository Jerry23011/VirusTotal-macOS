//
//  MiniModeButtonStyle.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniModeButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .padding(7)
            .frame(height: 36)
            .background(
                Group {
                    if isEnabled {
                        Color(.labelColor)
                            .opacity(configuration.isPressed ? 0.1 : 0.05)
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1.0 : 0.5)
    }
}

//
//  MiniModeButtonStyle.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-14.
//

import SwiftUI

struct MiniModeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .padding(7)
            .frame(height: 36)
            .background(Color(.labelColor).opacity(configuration.isPressed ? 0.1 : 0.05))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

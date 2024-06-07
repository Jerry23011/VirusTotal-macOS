//
//  View.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-30.
//

import SwiftUI

extension View {
    /// Given a binding condition, a key, and modifiers, set a keyboard shortcut for a textfield
    func focused(_ condition: FocusState<Bool>.Binding,
                 key: KeyEquivalent,
                 modifiers: EventModifiers = .command) -> some View {
        focused(condition)
            .background(
                Button("") {
                    condition.wrappedValue = true
                }
                    .keyboardShortcut(key, modifiers: modifiers)
                    .hidden()
            )
    }
}

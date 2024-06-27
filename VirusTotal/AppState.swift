//
//  AppState.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-10.
//

import SwiftUI

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var sidebarSearchFocused: Bool = false

    private init() {}
}

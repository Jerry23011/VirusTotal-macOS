//
//  AppState.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-10.
//

import SwiftUI

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var sidebarSearchFocused: Bool = false
    var selectedSidebarItem: ServiceSidebarItem?

    private init() {}
}

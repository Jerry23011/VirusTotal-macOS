//
//  AppState.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-10.
//

import SwiftUI
import Defaults

@MainActor
@Observable
final class AppState {
    static let shared = AppState()

    var sidebarSearchFocused: Bool = false
    var selectedSidebarItem: ServiceSidebarItem? {
        get {
            if #available(macOS 15, *) {
                return _selectedSidebarItem ?? navItemToSidebarItem()
            } else {
                return _selectedSidebarItem
            }
        }
        set {
            _selectedSidebarItem = newValue
        }
    }

    // MARK: Private
    private var _selectedSidebarItem: ServiceSidebarItem?
    private var startPage: NavigationItem { Defaults[.startPage] }

    /// Converts `NavigationItem` stored in Defaults into a `ServiceSidebarItem`
    private func navItemToSidebarItem() -> ServiceSidebarItem {
        switch startPage {
        case .home:
                .home
        case .file:
                .fileUpload
        case .url:
                .urlLookup
        }
    }
}

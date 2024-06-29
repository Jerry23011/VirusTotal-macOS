//
//  ToolsView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI

@MainActor
struct ToolsView: View {
    var searchText: String

    init(searchText: String) {
        self.searchText = searchText
    }

    var body: some View {
        Section {
            ForEach(filteredItems) { item in
                NavigationLink(destination: viewForSidebarItem(item)) {
                    Label(item.localizedText,
                          systemImage: item.systemImageName)
                }
                .tag(item)
            }
        }
    }

    @ViewBuilder
    private func viewForSidebarItem(_ item: SidebarItem) -> some View {
        switch item {
        case .history:
            ScanHistoryView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredItems: [SidebarItem] {
        SidebarItem.filtered(by: searchText, using: \.localizedText)
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case history = "sidebar.history"

        var id: String { self.rawValue }

        var localizedText: String {
            NSLocalizedString(self.rawValue, comment: "")
        }

        var systemImageName: String {
            switch self {
            case .history:
                return "book.closed"
            }
        }
    }
}

#Preview {
    ToolsView(searchText: "")
}

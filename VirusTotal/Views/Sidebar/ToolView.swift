//
//  ToolView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI

struct ToolView: View {
    var searchText: String

    init(searchText: String) {
        self.searchText = searchText
    }

    var body: some View {
        Section("sidebar.section.tools") {
            ForEach(filteredItems) { item in
                NavigationLink(destination: viewForSidebarItem(item)) {
                    Label(item.titleKey, systemImage: item.systemImageName)
                }
                .tag(item)
            }
        }
    }

    @ViewBuilder
    private func viewForSidebarItem(_ item: ServiceSidebarItem) -> some View {
        switch item {
        case .history:
            ScanHistoryView()
                .frame(minWidth: 600, minHeight: 500)
        case .log:
            LogView()
                .frame(minWidth: 600, minHeight: 500)
        default:
            EmptyView()
        }
    }

    private var filteredItems: [ServiceSidebarItem] {
        guard !searchText.isEmpty else { return ServiceSidebarItem.toolItems }
        return ServiceSidebarItem.toolItems.filter {
            $0.localizedText.localizedCaseInsensitiveContains(searchText)
        }
    }
}

#Preview {
    ToolView(searchText: "")
}

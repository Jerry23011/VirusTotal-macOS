//
//  SidebarView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI

struct SidebarView: View {
    @State private var searchText = ""

    var body: some View {
        VStack {
            List {
                Section {
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: viewForSidebarItem(item)) {
                            Label(item.localizedText, systemImage: item.systemImageName)
                        }
                        .tag(item)
                    }
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        }
        .searchable(text: $searchText, placement: .sidebar)
        .navigationSplitViewColumnWidth(200)
    }

    @ViewBuilder
    private func viewForSidebarItem(_ item: SidebarItem) -> some View {
        switch item {
        case .home:
            HomeView()
                .frame(minWidth: 600, minHeight: 500)
        case .fileUpload:
            FileView()
                .frame(minWidth: 600, minHeight: 500)
        case .urlLookup:
            URLView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredItems: [SidebarItem] {
        let items = SidebarItem.allCases
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { $0.localizedText.localizedCaseInsensitiveContains(searchText) }
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case home = "sidebar.home"
    case fileUpload = "sidebar.file"
    case urlLookup = "sidebar.url"

    var id: String { self.rawValue }

    var localizedText: String {
        NSLocalizedString(self.rawValue, comment: "")
    }

    var systemImageName: String {
        switch self {
        case .home:
            return "house"
        case .fileUpload:
            return "arrow.up.doc"
        case .urlLookup:
            return "link"
        }
    }
}

#Preview {
    SidebarView()
}

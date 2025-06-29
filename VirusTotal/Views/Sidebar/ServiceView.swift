//
//  ServiceView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI

struct ServiceView: View {
    var searchText: String

    init(searchText: String) {
        self.searchText = searchText
    }

    var body: some View {
        Section("sidebar.section.services") {
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
    private func viewForSidebarItem(_ item: ServiceSidebarItem) -> some View {
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
        case .fileBatch:
            FileBatchView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredItems: [ServiceSidebarItem] {
        ServiceSidebarItem.filtered(by: searchText, using: \.localizedText)
    }
}

enum ServiceSidebarItem: String, CaseIterable, Identifiable {
    case home = "sidebar.home"
    case fileUpload = "sidebar.file"
    case urlLookup = "sidebar.url"
    case fileBatch = "sidebar.batch"

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
        case .fileBatch:
            return "arrow.up.page.on.clipboard"
        }
    }
}

#Preview {
    ServiceView(searchText: "")
}

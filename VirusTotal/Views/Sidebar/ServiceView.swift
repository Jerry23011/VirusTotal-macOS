//
//  ServiceView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import SwiftUI
import Defaults

struct ServiceView: View {
    var searchText: String

    init(searchText: String) {
        self.searchText = searchText
    }

    var body: some View {
        Section("sidebar.section.services") {
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
        case .downloadsMonitor:
            DownloadsMonitorView()
                .frame(minWidth: 600, minHeight: 500)
        case .history:
            ScanHistoryView()
                .frame(minWidth: 600, minHeight: 500)
        case .log:
            LogView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    private var filteredItems: [ServiceSidebarItem] {
        guard !searchText.isEmpty else { return ServiceSidebarItem.serviceItems }
        return ServiceSidebarItem.serviceItems.filter {
            $0.localizedText.localizedCaseInsensitiveContains(searchText)
        }
    }
}

enum ServiceSidebarItem: String, CaseIterable, Identifiable {
    case home = "sidebar.home"
    case fileUpload = "sidebar.file"
    case urlLookup = "sidebar.url"
    case fileBatch = "sidebar.batch"
    case downloadsMonitor = "sidebar.downloadsmonitor"
    case history = "sidebar.history"
    case log = "sidebar.log"

    var id: String { self.rawValue }

    static let serviceItems: [ServiceSidebarItem] = [.home, .fileUpload, .urlLookup, .fileBatch, .downloadsMonitor]
    static let toolItems: [ServiceSidebarItem] = [.history, .log]

    var titleKey: LocalizedStringKey {
        LocalizedStringKey(rawValue)
    }

    var localizedText: String {
        Defaults[.appLanguage].localizedString(forKey: rawValue)
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
        case .downloadsMonitor:
            return "folder.badge.gearshape"
        case .history:
            return "book.closed"
        case .log:
            return "doc.text"
        }
    }
}

#Preview {
    ServiceView(searchText: "")
}

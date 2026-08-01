//
//  SidebarView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI

struct SidebarView: View {
    @Bindable private var appState = AppState.shared
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $appState.selectedSidebarItem) {
                ServiceView(searchText: searchText)
                ToolView(searchText: searchText)
            }
            .listStyle(.sidebar)
            .searchable(text: $searchText,
                        isPresented: $appState.sidebarSearchFocused,
                        placement: .sidebar)

            Divider()

            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(minWidth: 200)
        .navigationSplitViewColumnWidth(200)
    }
}

#Preview {
    SidebarView()
}

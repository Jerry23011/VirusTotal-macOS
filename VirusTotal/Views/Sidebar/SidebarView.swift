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
        List(selection: $appState.selectedSidebarItem) {
            ServiceView(searchText: searchText)
            ToolView(searchText: searchText)
        }
        .listStyle(.sidebar)
        .frame(minWidth: 200)
        .searchable(text: $searchText,
                    isPresented: $appState.sidebarSearchFocused,
                    placement: .sidebar)
        .navigationSplitViewColumnWidth(200)
    }
}

#Preview {
    SidebarView()
}

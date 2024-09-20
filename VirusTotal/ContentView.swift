//
//  ContentView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI
import Defaults

struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .frame(minWidth: 200)
        } detail: {
            detail
                .frame(minWidth: 600, minHeight: 500)
        }
    }

    // MARK: ViewBuilder
    @ViewBuilder
    private var detail: some View {
        switch startPage {
        case .home:
            HomeView()
        case .file:
            FileView()
        case .url:
            URLView()
        }
    }

    // MARK: Private
    private var startPage: NavigationItem { Defaults[.startPage] }
}

 #Preview {
     ContentView()
 }

//
//  ContentView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-19.
//

import SwiftUI

struct ContentView: View {
    @State private var columnVisibility: NavigationSplitViewVisibility = .doubleColumn

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .frame(minWidth: 200)
        } detail: {
            HomeView()
                .frame(minWidth: 600, minHeight: 500)
        }
    }
}

 #Preview {
     ContentView()
 }

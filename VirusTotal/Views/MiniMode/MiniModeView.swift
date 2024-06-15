//
//  MiniModeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-13.
//

import SwiftUI

struct MiniModeView: View {
    @State private var tabSelection: MiniTab = .file

    var body: some View {
        TabView(selection: $tabSelection) {
            MiniHomeView()
                .tabItem {
                    Label("sidebar.home", systemImage: "house.fill")
                }
                .tag(MiniTab.home)
            MiniFileView()
                .tabItem {
                    Label("sidebar.file", systemImage: "arrow.up.doc.fill")
                }
                .tag(MiniTab.file)
            MiniURLView()
                .tabItem {
                    Label("sidebar.url", systemImage: "link")
                }
                .tag(MiniTab.url)
        }
        .task {
            if let window = NSApp.findWindow(WindowID.main) {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
            }
        }
    }
}

enum MiniTab {
    case home
    case file
    case url
}

#Preview {
    MiniModeView()
        .frame(width: 350, height: 250)
}

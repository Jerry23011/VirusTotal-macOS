//
//  MiniModeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-13.
//

import SwiftUI

struct MiniModeView: View {
    var body: some View {
        if #available(macOS 15.0, *) {
            legacyTab
// Enable code below after Xcode 16's official release
//            TabView {
//                Tab("sidebar.home", systemImage: "house.fill") {
//                    MiniHomeView()
//                }
//                Tab("sidebar.file", systemImage: "arrow.up.doc.fill") {
//                    MiniFileView()
//                }
//                Tab("sidebar.url", systemImage: "link") {
//                    MiniURLView()
//                }
//            }
            .task {
                if let window = NSApp.findWindow(WindowID.main) {
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                }
            }
        } else {
            legacyTab // For macOS 14
            .task {
                if let window = NSApp.findWindow(WindowID.main) {
                    window.titleVisibility = .hidden
                    window.titlebarAppearsTransparent = true
                }
            }
        }
    }
}

@ViewBuilder
private var legacyTab: some View {
    TabView {
        MiniHomeView()
            .tabItem {
                Label("sidebar.home", systemImage: "house.fill")
            }
        MiniFileView()
            .tabItem {
                Label("sidebar.file", systemImage: "arrow.up.doc.fill")
            }
        MiniURLView()
            .tabItem {
                Label("sidebar.url", systemImage: "link")
            }
    }
}

#Preview {
    MiniModeView()
        .frame(width: 350, height: 250)
}

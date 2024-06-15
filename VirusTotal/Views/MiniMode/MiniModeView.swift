//
//  MiniModeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-13.
//

import SwiftUI

struct MiniModeView: View {
    var body: some View {
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
        .task {
            if let window = NSApp.findWindow(WindowID.main) {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
            }
        }
    }
}

#Preview {
    MiniModeView()
        .frame(width: 350, height: 250)
}

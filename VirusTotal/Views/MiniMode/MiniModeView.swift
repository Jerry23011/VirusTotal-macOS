//
//  MiniModeView.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-13.
//

import SwiftUI

struct MiniModeView: View {
    @StateObject private var tabModel: TabModel = .init()
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        TabView(selection: $tabModel.activeTab) {
            MiniHomeView()
                .tag(Tab.home)
            MiniFileView()
                .tag(Tab.file)
                .background(HideTabBar())
            MiniURLView()
                .tag(Tab.url)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button("", systemImage: "sidebar.left") {
                    tabModel.hideTabBar.toggle()
                }
            }
        }
        .background {
            GeometryReader {
                let rect = $0.frame(in: .global)

                Color.clear
                    .onChange(of: rect) {
                        tabModel.updateTabPosition()
                    }
            }
        }
        .onChange(of: controlActiveState) {_, newValue in
            if newValue == .key {
                tabModel.addTabBar()
                tabModel.isTabBarAdded = true
            }
        }
        .task {
            if let window = NSApp.findWindow(WindowID.main) {
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                if #available(macOS 15.0, *) {
                    // Removes the default tab bar on macOS 15.0+
                    window.toolbar?.removeItem(at: 0)
                }
            }
        }
    }
}

#Preview {
    MiniModeView()
        .frame(width: 350, height: 250)
}

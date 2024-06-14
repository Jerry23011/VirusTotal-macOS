//
//  TabModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-13.
//

import SwiftUI

class TabModel: ObservableObject {
    @Published var activeTab: Tab = .file
    @Published var isTabBarAdded: Bool = false
    @Published var hideTabBar: Bool = false

    func addTabBar() {
        guard !isTabBarAdded else { return }

        if let applicationWindow = NSApplication.shared.mainWindow {
            let customTabBar = NSHostingView(rootView: FloatingTabBarView().environmentObject(self))
            let floatingWindow = NSWindow()
            floatingWindow.styleMask = .borderless
            floatingWindow.contentView = customTabBar
            floatingWindow.backgroundColor = .clear
            floatingWindow.title = windowID
            let windowSize = applicationWindow.frame.size
            let windowOrigin = applicationWindow.frame.origin

            floatingWindow.setFrameOrigin(
                .init(x: windowOrigin.x - 50,
                      y: windowOrigin.y + (windowSize.height - tabBarHeight) / 2)
            )

            applicationWindow.addChildWindow(floatingWindow, ordered: .above)
        } else {
            log.error("MiniMode TabView can't find window.")
        }
    }

    func updateTabPosition() {
        if let floatingWindow = NSApplication.shared.windows.first(
            where: { $0.title == windowID }
        ),
            let applicationWindow = NSApplication.shared.mainWindow {
            let windowSize = applicationWindow.frame.size
            let windowOrigin = applicationWindow.frame.origin

            floatingWindow.setFrameOrigin(
                .init(x: windowOrigin.x - 50,
                      y: windowOrigin.y + (windowSize.height - tabBarHeight) / 2)
            )
        }
    }

    // MARK: Private
    private let windowID = WindowID.miniTabBar.rawValue
    private let tabBarHeight = CGFloat(Tab.allCases.count * 45)
}

enum Tab: String, CaseIterable {
    case home = "house.fill"
    case file = "arrow.up.doc.fill"
    case url = "link"
}

struct HideTabBar: NSViewRepresentable {
    func makeNSView(context: Context) -> some NSView {
        return .init()
    }
    func updateNSView(_ nsView: NSViewType, context: Context) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            if let tabView = nsView.superview?.superview?.superview as? NSTabView {
                tabView.tabViewType = .noTabsNoBorder
                tabView.tabViewBorderType = .none
                tabView.tabPosition = .none
            }
        }
    }
}

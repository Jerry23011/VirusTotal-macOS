//
//  WindowManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-30.
//

import SwiftUI
import AppKit

class WindowManager {
    static func showURLWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 530),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.center()
        window.contentView = NSHostingView(rootView: URLView())
        window.makeKeyAndOrderFront(nil)
    }

    static func showFileWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 530),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.isOpaque = true
        window.center()
        window.contentView = NSHostingView(rootView: FileView())
        window.makeKeyAndOrderFront(nil)
    }
}

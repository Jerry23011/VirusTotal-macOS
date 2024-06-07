//
//  NSApplication.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-04.
//

import Cocoa

extension NSApplication {
    /// Given a WindowID, return the corresponding NSWindow
    func findWindow(_ id: WindowID) -> NSWindow? {
        windows.first { $0.identifier?.rawValue == id.rawValue }
    }
}

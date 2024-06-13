//
//  URL.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-13.
//

import Cocoa

extension URL {
    /// Open a directory URL in Finder
    func openInFinder() {
        if FileManager.default.fileExists(atPath: self.path) {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: self.path)
        } else {
            log.error("Directory doesn't exist \(self)")
        }
    }
}

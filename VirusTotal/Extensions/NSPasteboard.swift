//
//  NSPasteboard.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-05.
//

import Cocoa
import UniformTypeIdentifiers

extension NSPasteboard {
    /// Get the file URLs from dragged and dropped files.
    func fileURLs(contentTypes: [UTType] = []) -> [URL] {
        var options: [ReadingOptionKey: Any] = [
            .urlReadingFileURLsOnly: true
        ]

        if !contentTypes.isEmpty {
            options[.urlReadingContentsConformToTypes] = contentTypes.map(\.identifier)
        }

        guard let urls = readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
            return []
        }

        return urls
    }
}

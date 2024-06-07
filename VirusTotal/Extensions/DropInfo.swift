//
//  DropInfo.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-05.
//

import SwiftUI
import UniformTypeIdentifiers

extension DropInfo {
    /// Given an array of UTType, return an array of URL that confirms to the array of UTType
    func fileURLsConforming(to contentTypes: [UTType]) -> [URL] {
        NSPasteboard(name: .drag).fileURLs(contentTypes: contentTypes)
    }

    /// Given an array of UTType, return true if any URL matches the content types, return
    /// false otherwise
    func hasFileURLsConforming(to contentTypes: [UTType]) -> Bool {
        !fileURLsConforming(to: contentTypes).isEmpty
    }
}

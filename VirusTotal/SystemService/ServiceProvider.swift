//
//  ServiceProvider.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//

import Cocoa
import SwiftUI

@MainActor
class ServiceProvider: NSObject {
    private let urlViewModel = URLViewModel.shared
    private let fileViewModel = FileViewModel.shared

    @objc
    func scanURLService(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        guard let url = pasteboard.string(forType: .string) else {
            return
        }

        Task {
            WindowManager.showURLWindow()
            urlViewModel.inputURL = url
            urlViewModel.startURLAnalysis()
        }
    }

    @objc
    func scanFileService(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        guard let url = pasteboard.string(forType: .fileURL) else {
            return
        }

        Task {
            WindowManager.showFileWindow()
            let fileURL = URL(string: url)
            let defaultFileURL = URL(string: "file://")!
            await fileViewModel.handleFileImport(fileURL ?? defaultFileURL)
        }
    }
}

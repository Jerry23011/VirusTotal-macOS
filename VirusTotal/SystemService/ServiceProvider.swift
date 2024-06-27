//
//  ServiceProvider.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//

import Cocoa
import SwiftUI

class ServiceProvider: NSObject {
    private var urlViewModel = URLViewModel.shared
    private var fileViewModel = AnalyzeFileViewModel.shared

    @objc
    func scanURLService(_ pasteboard: NSPasteboard, userData: String, error: NSErrorPointer) {
        guard let url = pasteboard.string(forType: .string) else {
            return
        }

        Task { @MainActor in
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

        Task { @MainActor in
            WindowManager.showFileWindow()
            let fileURL = URL(string: url)
            let defaultFileURL = URL(string: "file://")!
            fileViewModel.handleFileImport(fileURL ?? defaultFileURL)
        }
    }
}

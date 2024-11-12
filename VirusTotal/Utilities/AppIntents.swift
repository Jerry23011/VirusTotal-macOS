//
//  AppIntents.swift
//  VirusTotal
//
//  Created by Jerry on 2024-11-12.
//

import AppIntents

struct ScanFileIntent: AppIntent {

    static let title: LocalizedStringResource = "intent.file.title"
    static let description: LocalizedStringResource = "intent.file.descr"

    static let openAppWhenRun: Bool = true

    @Parameter(
        title: "intent.file.title",
        supportedTypeIdentifiers: ["public.data"],
        inputConnectionBehavior: .connectToPreviousIntentResult
    )
    var fileURL: IntentFile?

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let fileURL = fileURL?.fileURL else {
            let error = VTError.intent("No file or wrong file type provided")
            log.error(error)
            throw error
        }

        AppState.shared.selectedSidebarItem = .fileUpload
        await FileViewModel.shared.handleFileImport(fileURL)

        return .result()
    }
}

struct VTShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanFileIntent(),
            phrases: [
                "Scan file with \(.applicationName)"
            ],
            shortTitle: "intent.file.short.title",
            systemImageName: "doc.text.magnifyingglass"
        )
    }
}

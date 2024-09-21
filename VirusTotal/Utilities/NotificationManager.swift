//
//  NotificationManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-09-21.
//

import Cocoa
import SwiftUI
import NotchNotification

@MainActor
final class NotificationManager {

    static func success(_ message: LocalizedStringKey) {
        guard !NSApplication.shared.isActive else {
            return
        }
        NotchNotification.present(
            trailingView: Image(systemName: "checkmark")
                .foregroundStyle(.green),
            bodyView: Text(message)
        )
    }

    static func stringError(_ message: String) {
        guard !NSApplication.shared.isActive else {
            return
        }
        NotchNotification.present(
            error: message
        )
    }

    static func error(_ error: Error) {
        guard !NSApplication.shared.isActive else {
            return
        }
        NotchNotification.present(
            error: error
        )
    }
}

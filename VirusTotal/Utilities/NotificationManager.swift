//
//  NotificationManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-10-26.
//

import UserNotifications
import Defaults

final actor NotificationManager {
    /// Requests user permission to display notifications with sounds, badges, and alerts.
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()

        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            log.info("Notification authorization succeeded")
        } catch {
            log.warning("Notification authorization failed")
        }
    }

    /// Given a title, optional subtitle, and optional body, pushes a local notification
    static func pushNotification(title: String, subtitle: String? = nil, body: String? = nil) async {
        guard await isAuthorized else {
            log.info("Notification not authorized")
            return
        }
        guard enableNotification else {
            log.info("Notification disabled in app settings")
            return
        }
        do {
            let content = UNMutableNotificationContent()

            content.title = title
            content.sound = UNNotificationSound.default

            if let subtitle {
                content.subtitle = subtitle
            }
            if let body {
                content.body = body
            }

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            try await UNUserNotificationCenter.current().add(request)
        } catch {
            log.error(error.localizedDescription)
        }
    }

    // MARK: Private
    private static var isAuthorized: Bool {
        get async {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            return settings.authorizationStatus == .authorized
        }
    }
    private static var enableNotification: Bool {
        Defaults[.enableNotification]
    }
}

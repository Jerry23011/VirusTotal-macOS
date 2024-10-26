//
//  NotificationManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-10-26.
//

import UserNotifications

final actor NotificationManager {
    /// Requests user permission to display notifications with sounds, badges, and alerts.
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()

        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            self.isAuthorized = true
            log.info("Notification Authorization: \(self.isAuthorized)")
        } catch {
            self.isAuthorized = false
            log.warning("Notification Authorization: \(self.isAuthorized)")
        }
    }

    /// Given a title, optional subtitle, and optional body, pushes a local notification
    static func pushNotification(title: String, subtitle: String? = nil, body: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle {
            content.subtitle = subtitle
        }
        if let body {
            content.body = body
        }
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Private
    private static var isAuthorized: Bool = false
}

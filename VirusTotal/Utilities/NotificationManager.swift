//
//  NotificationManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-10-26.
//

import AppKit
import UserNotifications
import Defaults

final actor NotificationManager {
    /// Requests user permission to display notifications with sounds, badges, and alerts.
    static func requestAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else {
            log.info("Notification authorization status: \(settings.authorizationStatus.rawValue)")
            return
        }

        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            log.info("Notification authorization \(granted ? "granted" : "denied")")
        } catch {
            log.warning("Notification authorization failed: \(error)")
        }
    }

    /// Given a title, optional subtitle, and optional body, pushes a local notification
    static func pushNotification(
        title: String,
        subtitle: String? = nil,
        body: String? = nil,
        userInfo: [String: String] = [:]
    ) async {
        guard canPushNotification else {
            log.info("Notification disabled in app settings")
            return
        }

        guard await shouldPushNotificationForAppState else {
            log.info("Notification suppressed while app is active")
            return
        }

        guard await canDeliverNotifications else { return }

        do {
            let content = UNMutableNotificationContent()

            content.title = title
            content.sound = UNNotificationSound.default
            content.userInfo = userInfo

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
            log.info("Notification queued: \(title)")
        } catch {
            log.error("Failed to queue notification: \(error.localizedDescription)")
        }
    }

    // MARK: Private

    private static var canDeliverNotifications: Bool {
        get async {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return true
            case .notDetermined:
                await requestAuthorization()
                let updatedSettings = await center.notificationSettings()
                return canDeliverNotifications(for: updatedSettings.authorizationStatus)
            case .denied:
                log.info("Notification denied in System Settings")
                return false
            @unknown default:
                log.info("Unknown notification authorization status: \(settings.authorizationStatus.rawValue)")
                return false
            }
        }
    }

    private static func canDeliverNotifications(for status: UNAuthorizationStatus) -> Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }

    private static var canPushNotification: Bool {
        Defaults[.enableNotification]
    }

    private static var shouldPushNotificationForAppState: Bool {
        get async {
            await MainActor.run { !NSApp.isActive }
        }
    }
}

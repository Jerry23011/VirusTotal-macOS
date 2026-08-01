//
//  AppDelegate.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-26.
//

import Cocoa
import Defaults
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var didHideInitialBackgroundWindow = false
    private let notificationDelegate = NotificationCenterDelegate()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = ServiceProvider()
        configureBackgroundMode()
        observeBackgroundModeChanges()
        UNUserNotificationCenter.current().delegate = notificationDelegate
    }

    func applicationDidUpdate(_ notification: Notification) {
        guard let mainWindow = NSApp.findWindow(WindowID.main) else { return }
        mainWindow.delegate = self

        if Defaults[.showMainWindowOnNextLaunch] {
            Defaults[.showMainWindowOnNextLaunch] = false
            showMainWindow()
            return
        }

        if Defaults[.backgroundMonitoringMode], !didHideInitialBackgroundWindow {
            didHideInitialBackgroundWindow = true
            mainWindow.orderOut(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showMainWindow()
        }
        return true
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard Defaults[.backgroundMonitoringMode], sender.identifier?.rawValue == WindowID.main.rawValue else {
            return true
        }

        sender.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
        return false
    }

    private func observeBackgroundModeChanges() {
        NotificationCenter.default.addObserver(
            forName: .backgroundMonitoringModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.configureBackgroundMode(shouldApplyAccessoryPolicy: false)
            }
        }
    }

    private func configureBackgroundMode(shouldApplyAccessoryPolicy: Bool = true) {
        if Defaults[.backgroundMonitoringMode] {
            if shouldApplyAccessoryPolicy {
                NSApp.setActivationPolicy(.accessory)
            }
            configureStatusItem()
        } else {
            NSApp.setActivationPolicy(.regular)
            removeStatusItem()
            didHideInitialBackgroundWindow = false
        }
    }

    private func configureStatusItem() {
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            let image = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "shield.lefthalf.filled", accessibilityDescription: "VirusTotal")
            image?.size = NSSize(width: 18, height: 18)
            image?.isTemplate = true
            statusItem?.button?.image = image
            statusItem?.button?.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(statusMenuItem(title: "Open VirusTotal", action: #selector(openMainWindowFromMenu)))
        menu.addItem(statusMenuItem(title: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(statusMenuItem(title: "Quit VirusTotal", action: #selector(quitFromMenu), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    private func statusMenuItem(title: String, action: Selector, keyEquivalent: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        return item
    }

    private func removeStatusItem() {
        guard let statusItem else { return }
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
    }

    @objc private func openMainWindowFromMenu() {
        showMainWindow()
        NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
    }

    @objc private func openSettingsFromMenu() {
        showRegularAppUI()
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
    }

    @objc private func quitFromMenu() {
        NSApp.terminate(nil)
    }

    private func showMainWindow() {
        showRegularAppUI()
        NSApp.findWindow(WindowID.main)?.makeKeyAndOrderFront(nil)
    }

    private func showRegularAppUI() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        let isAppActive = await MainActor.run { NSApp.isActive }
        return isAppActive ? [] : [.banner, .list, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard userInfo["destination"] as? String == "downloadsMonitor" else { return }

        let filePath = userInfo["filePath"] as? String
        let sha256 = userInfo["sha256"] as? String

        await MainActor.run {
            var payload: [AnyHashable: Any] = [:]
            if let filePath { payload["filePath"] = filePath }
            if let sha256 { payload["sha256"] = sha256 }

            DownloadsMonitorViewModel.shared.handleNotificationSelection(filePath: filePath)
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            AppState.shared.selectedSidebarItem = .downloadsMonitor
            NotificationCenter.default.post(name: .openMainWindowRequested, object: nil)
            NotificationCenter.default.post(
                name: .downloadsMonitorFileRequested,
                object: nil,
                userInfo: payload
            )
        }
    }
}

extension Notification.Name {
    static let backgroundMonitoringModeChanged = Notification.Name("backgroundMonitoringModeChanged")
    static let openMainWindowRequested = Notification.Name("openMainWindowRequested")
    static let openSettingsRequested = Notification.Name("openSettingsRequested")
    static let downloadsMonitorFileRequested = Notification.Name("downloadsMonitorFileRequested")
}

//
//  Defaults.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-23.
//

import Defaults
import Foundation

extension Defaults.Keys {

    // Cache quota usage for HomeView
    static let hourlyQuota = Key<UserQuota>("hourlyQuota",
                                            default: UserQuota(used: 0, allowed: 240))
    static let dailyQuota = Key<UserQuota>("dailyQuota",
                                           default: UserQuota(used: 0, allowed: 500))
    static let monthlyQuota = Key<UserQuota>("monthlyQuota",
                                             default: UserQuota(used: 0, allowed: 15_500))

    // Store VT API Key and Username
    static let apiKey = Key<String>("apiKey", default: "")
    static let userName = Key<String>("userName", default: "")

    // Onboarding
    static let appFirstLaunch = Key<Bool>("appFirstLaunch", default: true)

    // General Settings
    static let cleanURL = Key<Bool>("cleanURL", default: false)
    static let startPage = Key<NavigationItem>("startPage", default: .home)
    static let enableNotification = Key<Bool>("enableNotification", default: true)
    static let autoScanDownloadsEnabled = Key<Bool>("autoScanDownloadsEnabled", default: false)
    static let autoScanDownloadsFolderPath = Key<String>("autoScanDownloadsFolderPath", default: "")
    static let autoScanDownloadsFolderBookmark = Key<String>("autoScanDownloadsFolderBookmark", default: "")
    static let downloadMonitorFileCategories = Key<[DownloadMonitorFileCategory]>(
        "downloadMonitorFileCategories",
        default: [.archives, .applications]
    )
    static let backgroundMonitoringMode = Key<Bool>("backgroundMonitoringMode", default: false)
    static let showMainWindowOnNextLaunch = Key<Bool>("showMainWindowOnNextLaunch", default: false)
    static let appLanguage = Key<AppLanguage>("appLanguage", default: .english)

    // Advanced Settings
    static let miniMode = Key<Bool>("miniMode", default: false)
}

enum NavigationItem: String, CaseIterable, Identifiable, Defaults.Serializable {
    case home, file, url, fileBatch
    var id: Self { self }
}

enum AppLanguage: String, CaseIterable, Identifiable, Defaults.Serializable {
    case english = "en"
    case czech = "cs"
    case simplifiedChinese = "zh-Hans"
    case russian = "ru"

    var id: Self { self }

    var displayName: String {
        switch self {
        case .english:
            return "English"
        case .czech:
            return "Čeština"
        case .simplifiedChinese:
            return "简体中文"
        case .russian:
            return "Русский"
        }
    }

    func apply() {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}

enum DownloadMonitorFileCategory: String, CaseIterable, Identifiable, Defaults.Serializable {
    case archives
    case applications
    case documents
    case images
    case audio
    case video
    case other

    var id: Self { self }
}

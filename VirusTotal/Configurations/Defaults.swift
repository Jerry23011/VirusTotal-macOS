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

    // Store VT Username. The API key is stored in Keychain.
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
    static let didConfirmAutoScanUploads = Key<Bool>("didConfirmAutoScanUploads", default: false)
    static let downloadMonitorFileCategories = Key<[DownloadMonitorFileCategory]>(
        "downloadMonitorFileCategories",
        default: [.archives, .applications]
    )
    static let backgroundMonitoringMode = Key<Bool>("backgroundMonitoringMode", default: false)
    static let showMainWindowOnNextLaunch = Key<Bool>("showMainWindowOnNextLaunch", default: false)
    static let appLanguage = Key<AppLanguage>("appLanguage", default: AppLanguage.defaultLanguage)

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

    static var defaultLanguage: AppLanguage {
        preferredSupportedLanguage(from: Locale.preferredLanguages) ?? .english
    }

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

    static func synchronizePreference() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "appLanguage") == nil {
            let preferredLanguages = defaults.stringArray(forKey: "AppleLanguages") ?? Locale.preferredLanguages
            Defaults[.appLanguage] = preferredSupportedLanguage(from: preferredLanguages) ?? defaultLanguage
        }

        Defaults[.appLanguage].apply()
    }

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    func localizedString(forKey key: String, table: String? = nil) -> String {
        if let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            let value = bundle.localizedString(forKey: key, value: nil, table: table)
            if value != key {
                return value
            }
        }

        return String(localized: String.LocalizationValue(key))
    }

    func apply() {
        UserDefaults.standard.set([rawValue], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }

    private static func preferredSupportedLanguage(from languageIdentifiers: [String]) -> AppLanguage? {
        languageIdentifiers.compactMap(AppLanguage.init(languageIdentifier:)).first
    }

    private init?(languageIdentifier: String) {
        let normalizedIdentifier = languageIdentifier.replacingOccurrences(of: "_", with: "-")
        if let language = AppLanguage.allCases.first(where: {
            normalizedIdentifier == $0.rawValue || normalizedIdentifier.hasPrefix("\($0.rawValue)-")
        }) {
            self = language
            return
        }

        return nil
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

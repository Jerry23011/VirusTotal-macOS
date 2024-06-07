//
//  Defaults.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-23.
//

import Defaults

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

    // Advanced Settings
    static let miniMode = Key<Bool>("miniMode", default: false)
}

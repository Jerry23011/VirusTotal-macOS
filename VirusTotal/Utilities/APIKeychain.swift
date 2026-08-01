//
//  APIKeychain.swift
//  VirusTotal
//
//  Created by OpenAI on 2026-08-01.
//

import Foundation
import Security

enum APIKeychain {
    static var apiKey: String {
        do {
            return try readAPIKey()
        } catch {
            log.error(error)
            return ""
        }
    }

    static func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)

        if apiKey.isEmpty {
            try deleteAPIKey()
            return
        }

        var query = baseQuery
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try updateAPIKey(data)
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    static func migrateAPIKeyFromDefaultsIfNeeded() {
        migrateAPIKeyFromDefaultsIfPresent()
        migrateAPIKeyFromLegacyKeychainIfNeeded()
    }

    private static let service = Bundle.main.bundleIdentifier ?? "VirusTotal"
    private static let account = "VirusTotal API Key"
    private static let legacyDefaultsKey = "apiKey"

    private static var baseQuery: [String: Any] {
        var query = legacyBaseQuery
        query[kSecUseDataProtectionKeychain as String] = true
        return query
    }

    private static var legacyBaseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func migrateAPIKeyFromDefaultsIfPresent() {
        let defaults = UserDefaults.standard
        guard let storedAPIKey = defaults.string(forKey: legacyDefaultsKey), !storedAPIKey.isEmpty else { return }
        guard apiKey.isEmpty else {
            defaults.removeObject(forKey: legacyDefaultsKey)
            return
        }

        do {
            try saveAPIKey(storedAPIKey)
            defaults.removeObject(forKey: legacyDefaultsKey)
        } catch {
            log.error(error)
        }
    }

    private static func migrateAPIKeyFromLegacyKeychainIfNeeded() {
        guard apiKey.isEmpty else { return }

        do {
            let legacyAPIKey = try readAPIKey(from: legacyBaseQuery)
            guard !legacyAPIKey.isEmpty else { return }
            try saveAPIKey(legacyAPIKey)
            try deleteAPIKey(from: legacyBaseQuery)
        } catch {
            log.error(error)
        }
    }

    private static func readAPIKey() throws -> String {
        try readAPIKey(from: baseQuery)
    }

    private static func readAPIKey(from baseQuery: [String: Any]) throws -> String {
        var query = baseQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let apiKey = String(data: data, encoding: .utf8) else {
                throw KeychainError.invalidData
            }
            return apiKey
        case errSecItemNotFound:
            return ""
        default:
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func updateAPIKey(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        let status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledStatus(status)
        }
    }

    private static func deleteAPIKey() throws {
        try deleteAPIKey(from: baseQuery)
    }

    private static func deleteAPIKey(from baseQuery: [String: Any]) throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledStatus(status)
        }
    }
}

enum KeychainError: LocalizedError {
    case invalidData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "The API key stored in Keychain is not valid UTF-8 data."
        case .unhandledStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

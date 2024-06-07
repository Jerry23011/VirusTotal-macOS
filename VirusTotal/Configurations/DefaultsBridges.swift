//
//  DefaultsBridges.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-23.
//

import Defaults

struct UserQuotaBridge: Defaults.Bridge {
    typealias Value = UserQuota
    typealias Serializable = [String: Int]

    func serialize(_ value: UserQuota?) -> Serializable? {
        guard let value = value else { return nil }
        return [
            "used": value.used,
            "allowed": value.allowed
        ]
    }

    func deserialize(_ object: Serializable?) -> UserQuota? {
        guard let object = object,
              let used = object["used"],
              let allowed = object["allowed"] else { return nil }
        return UserQuota(used: used, allowed: allowed)
    }
}

extension UserQuota: Defaults.Serializable {
    static let bridge = UserQuotaBridge()
}

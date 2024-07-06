//
//  CaseIterable.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-30.
//

import Foundation

extension CaseIterable where Self: Identifiable {
    /// Given a search text and a key path to a String property of the enum,
    /// returns an array of enum cases where the specified property contains the search text.
    nonisolated static func filtered(by searchText: String,
                                     using keyPath: KeyPath<Self, String>) -> [Self] {
        let items = Array(Self.allCases)
        guard !searchText.isEmpty else { return items }
        return items.filter { $0 [keyPath: keyPath]
            .localizedCaseInsensitiveContains(searchText) }
    }
}

//
//  SecurityScopedBookmark.swift
//  VirusTotal
//

import Foundation

enum SecurityScopedBookmark {
    static func encodedString(for url: URL) throws -> String {
        try bookmarkData(for: url).base64EncodedString()
    }

    static func resolveURL(from encodedString: String) throws -> URL? {
        guard !encodedString.isEmpty,
              let data = Data(base64Encoded: encodedString) else { return nil }

        do {
            return try resolveURL(from: data, options: .withSecurityScope)
        } catch {
            return try resolveURL(from: data, options: [])
        }
    }

    private static func bookmarkData(for url: URL) throws -> Data {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return try url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
    }

    private static func resolveURL(from data: Data, options: URL.BookmarkResolutionOptions) throws -> URL {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: options,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )

        return url
    }
}

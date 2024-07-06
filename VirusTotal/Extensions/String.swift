//
//  String - Strip.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-22.
//

import Foundation

extension String {
    /// Encode a String into base64 with String? as output type
    func toBase64() -> String? {
        data(using: .utf8)?.base64EncodedString()
    }

    /// Strip characters given in the parameter and output a new String
    func strip(_ character: Character) -> String {
        return replacingOccurrences(of: String(character), with: "")
    }

    /// Replace a given character with another given character
    func replace(_ character: Character, with replacement: Character) -> String {
        return replacingOccurrences(of: String(character), with: String(replacement))
    }

    /// Localize `String` with `NSLocalizedString`
    var nslocalized: String {
        return NSLocalizedString(self, comment: self)
    }
}

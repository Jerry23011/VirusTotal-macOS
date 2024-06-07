//
//  CustomTypes.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import Foundation

extension URLAnalysisStats {
    var allFlags: [Int] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap { $0.value as? Int }
    }
}

extension FileAnalysisStats {
    var allFlags: [Int] {
        let mirror = Mirror(reflecting: self)
        return mirror.children.compactMap { $0.value as? Int }
    }
}

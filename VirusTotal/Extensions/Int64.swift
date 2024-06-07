//
//  Int64.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-01.
//

import Foundation

extension Int64 {
    /// Use for Int64 type, display the value with unit
    func chooseUnit() -> String {
        switch self {
        case ..<1024: // bytes (1)
            return "\(self) B"
        case 1024 ..< 1_048_576: // KB (^2)
            return "\(self / 1024) KB"
        case 1_048_576 ..< 1_073_741_824: // MB (^3)
            return "\(self / 1_048_576) MB"
        case 1_073_741_824 ..< 1_099_511_627_776: // GB (^4)
            return "\(self / 1_073_741_824) G"
        default: // TB (^5)
            return "\(self / 1_099_511_627_776) T"
        }
    }
}

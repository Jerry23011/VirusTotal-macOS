//
//  ErrorManager.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-27.
//

import Foundation

enum Errors: Error {
    /// When POST request failed file uploading
    case upload(_ message: String)
    /// When the item has been reanalyzed for too many times
    /// and still has no valid results
    case timeout(_ message: String)
}

//
//  Double.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-03.
//

import Foundation

extension Double {
    /// Given a Unix timestamp, return the date in yyyy-MM-dd format
    func unixTimestampToDate() -> String {
        let date = Date(timeIntervalSince1970: self)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        return dateString
    }
}

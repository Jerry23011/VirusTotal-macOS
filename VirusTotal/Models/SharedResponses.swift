//
//  SharedResponses.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation

// MARK: Analysis Status

/// Shows the status of the analysis request
enum AnalysisStatus: Codable {
    case empty
    case loading
    case success
    case analyzing
    case upload
    case uploading
    case fail
}

// MARK: - Scan Response

/// Used to parse the response of the POST requests
struct ScanResponse: Decodable {
    let data: ScanData

    enum CodingKeys: String, CodingKey {
        case data
    }
}

struct ScanData: Codable {
    let type: String
    let id: String
}

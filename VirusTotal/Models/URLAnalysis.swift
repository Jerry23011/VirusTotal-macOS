//
//  URLAnalysis.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-07.
//

import Foundation
import Alamofire
import Defaults

actor URLAnalysis {
    static let shared = URLAnalysis()

    func analyzeURL(inputURL: String) async throws -> URLAnalysisResult {
        // VirusTotal accepts base64 encoded URL without `=`;
        // `/` in base64 also needs to be replaced by `_`
        let inputURLEncoded = inputURL.toBase64()?.strip("=").replace("/", with: "_") ?? ""
        let apiEndPoint = "https://www.virustotal.com/api/v3/urls/\(inputURLEncoded)"
        let headers: HTTPHeaders = ["x-apikey": apiKey]

        do {
            let analyses: AnalysisResponse = try await fetchAnalysis(
                url: apiEndPoint,
                method: .get,
                headers: headers
            )
            let alysAttrs = analyses.data.attributes
            return URLAnalysisResult(
                getReportSuccess: true,
                vtURL: makeVtURL(from: analyses.data.id),
                lastAnalysisStats: alysAttrs.lastAnalysisStats,
                lastAnalysisDate: alysAttrs.lastAnalysisDate?.unixTimestampToDate(),
                communityScore: alysAttrs.reputation,
                finalURL: alysAttrs.lastFinalURL,
                categories: extractCategory(alysAttrs.categories)
            )
        } catch {
            if let afError = error as? AFError, afError.responseCode == 404 {
                let uploadResult = try await uploadURL(inputURL: inputURL)
                if uploadResult.uploadSuccess == true {
                    // Wait for 2 seconds before firing request
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    return try await analyzeURL(inputURL: inputURL)
                } else {
                    throw VTError.upload(uploadResult.errorMessage ?? "Upload failed with unknown error.")
                }
            } else {
                throw error
            }
        }
    }

    func reanalyzeURL(inputURL: String) async throws {
            let inputURLEncoded = inputURL.toBase64()?.strip("=").replace("/", with: "_") ?? ""
            let apiEndPoint = "https://www.virustotal.com/api/v3/urls/\(inputURLEncoded)/analyse"
            let headers: HTTPHeaders = ["x-apikey": apiKey]

            _ = try await fetchAnalysis(url: apiEndPoint,
                                          method: .post,
                                          headers: headers) as ScanResponse
        }

    // MARK: Private

    private var apiKey: String { Defaults[.apiKey] }

    /// Given an inputURL, upload the URL to VirusTotal
    private func uploadURL(inputURL: String) async throws -> URLUploadResult {
            let apiEndPoint = "https://www.virustotal.com/api/v3/urls"
            let headers: HTTPHeaders = ["x-apikey": apiKey]

        _ = try await performUpload(apiEndPoint: apiEndPoint,
                                    inputURL: inputURL,
                                    headers: headers)

            return URLUploadResult(uploadSuccess: true)
        }

    /// Given a string, return a URL that can be opened in external browser
    /// to view analysis report on VirusTotal website
    private func makeVtURL(from id: String) -> String {
        return "https://www.virustotal.com/gui/url/\(id)"
    }

    /// Given a Dict, extract the value of the Dict and store it as a list of String
    private func extractCategory(_ dictionary: [String: String]) -> [String] {
        var categories: [String] = []
        for (_, value) in dictionary {
            categories.append(value)
        }
        return categories
    }
}

// MARK: Networking

/// Helper function to fetch analysis for analyzeURL() and reanalyzeURL()
private func fetchAnalysis<T: Decodable & Sendable>(
    url: String,
    method: HTTPMethod,
    headers: HTTPHeaders
) async throws -> T {
    return try await AF.request(
        url,
        method: method,
        encoding: URLEncoding.default,
        headers: headers
    )
        .validate()
        .serializingDecodable(T.self)
        .value
}

/// Helper function to upload URL for uploadURL()
private func performUpload(apiEndPoint: String, inputURL: String, headers: HTTPHeaders) async throws -> URLUploadResult {
    let parameters: Parameters = ["url": inputURL]

    _ = try await AF.request(
        apiEndPoint,
        method: .post,
        parameters: parameters,
        encoding: URLEncoding.default,
        headers: headers
    )
    .validate()
    .serializingDecodable(ScanResponse.self)
    .value

    return URLUploadResult(uploadSuccess: true)
}

// MARK: Results

struct URLAnalysisResult {
    var getReportSuccess: Bool?
    var statusMonitor: AnalysisStatus?
    var errorMessage: String?
    var vtURL: String?
    var lastAnalysisStats: URLAnalysisStats?
    var lastAnalysisDate: String?
    var communityScore: Int?
    var finalURL: String?
    var categories: [String]?
}

struct URLUploadResult {
    var statusMonitor: AnalysisStatus?
    var uploadSuccess: Bool?
    var errorMessage: String?
}

struct URLReanalyzeResult {
    var requestSuccess: Bool?
    var errorMessage: String?
}

// MARK: - Analysis Response

struct AnalysisResponse: Decodable {
    let data: AnalysisData

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct AnalysisData: Codable {
    let type: String
    let id: String
    let attributes: AnalysisAttributes
}

struct AnalysisAttributes: Codable {
    let lastAnalysisStats: URLAnalysisStats
    let lastAnalysisDate: Double?
    let lastFinalURL: String
    let reputation: Int
    let categories: [String: String]

    private enum CodingKeys: String, CodingKey {
        case lastAnalysisStats = "last_analysis_stats"
        case lastAnalysisDate = "last_analysis_date"
        case lastFinalURL = "last_final_url"
        case reputation = "reputation"
        case categories = "categories"
    }
}

struct URLAnalysisStats: Codable {
    let malicious: Int
    let suspicious: Int
    let undetected: Int
    let harmless: Int
    let timeout: Int
}

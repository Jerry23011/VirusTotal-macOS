//
//  AnalyzeURL.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-07.
//

import Foundation
import Alamofire
import Defaults

final class AnalyzeURL {
    static let shared = AnalyzeURL()

    private var apiKey: String { Defaults[.apiKey] }

    func analyzeURL(inputURL: String,
                    completion: @escaping(URLAnalysisResult) -> Void) {
        /// VirusTotal accepts base64 encoded URL without `=`
        /// `/` in the base64 code also needs to be replaced by `_`
        let inputURLEncoded = inputURL.toBase64()?.strip("=").replace("/", with: "_") ?? ""
        let apiEndPoint = "https://www.virustotal.com/api/v3/urls/\(inputURLEncoded)"
        let headers: HTTPHeaders = ["x-apikey": apiKey]

        AF.request(apiEndPoint, method: .get, headers: headers)
            .validate()
            .responseDecodable(of: AnalysisResponse.self) { [weak self] response in
                guard self != nil else { return }

                var urlAlysResult = URLAnalysisResult(getReportSuccess: nil,
                                                      statusMonitor: nil,
                                                      errorMessage: nil,
                                                      vtURL: nil,
                                                      lastAnalysisStats: nil,
                                                      lastAnalysisDate: nil,
                                                      communityScore: nil,
                                                      finalURL: nil)

                switch response.result {
                case.success(let analyses):
                    let alysAttrs = analyses.data.attributes
                    urlAlysResult.vtURL = self?.makeVtURL(from: analyses.data.id)
                    urlAlysResult.lastAnalysisDate = alysAttrs.lastAnalysisDate?.unixTimestampToDate()
                    urlAlysResult.lastAnalysisStats = alysAttrs.lastAnalysisStats
                    urlAlysResult.communityScore = alysAttrs.reputation
                    urlAlysResult.finalURL = alysAttrs.lastFinalURL
                    urlAlysResult.getReportSuccess = true
                    completion(urlAlysResult)
                case.failure(let error):
                    // If statusCode is 404 it means that the URL was never uploaded
                    if response.response?.statusCode == 404 {
                        self?.uploadURL(inputURL: inputURL) { uploadResult in
                            if uploadResult.uploadSuccess == true {
                                self?.retryAnalyzeURL(inputURL: inputURL,
                                                      completion: completion)
                            } else {
                                log.error(uploadResult.errorMessage ?? "Upload failed with unknown error.")
                                urlAlysResult.errorMessage = uploadResult.errorMessage
                                urlAlysResult.statusMonitor = uploadResult.statusMonitor
                                completion(urlAlysResult)
                            }
                        }
                    } else {
                        log.error(error)
                        urlAlysResult.errorMessage = error.localizedDescription
                        urlAlysResult.statusMonitor = .fail
                        completion(urlAlysResult)
                    }
                }
            }
    }

    func reanalyzeURL(inputURL: String,
                      completion: @escaping(URLReanalyzeResult) -> Void) {
        let inputURLEncoded = inputURL.toBase64()?.strip("=").replace("/", with: "_") ?? ""
        let apiEndPoint = "https://www.virustotal.com/api/v3/urls/\(inputURLEncoded)/analyse"
        let headers: HTTPHeaders = ["x-apikey": apiKey]

        AF.request(apiEndPoint, method: .post, headers: headers)
            .validate()
            .response { response in
                var reanalyzeResult = URLReanalyzeResult(requestSuccess: nil,
                                                         errorMessage: nil)

                switch response.result {
                case .success:
                    reanalyzeResult.requestSuccess = true
                case .failure(let error):
                    log.error(error)
                    reanalyzeResult.errorMessage = error.localizedDescription
                    reanalyzeResult.requestSuccess = false
                }
                completion(reanalyzeResult)
            }
    }

    // MARK: Private

    /// Given an inputURL, upload the URL to VirusTotal
    private func uploadURL(inputURL: String,
                           completion: @escaping (URLUploadResult) -> Void) {
        let apiEndPoint = "https://www.virustotal.com/api/v3/urls"
        let parameters: Parameters = ["url": inputURL]
        let headers: HTTPHeaders = ["x-apikey": apiKey]

        AF.request(
            apiEndPoint,
            method: .post,
            parameters: parameters,
            encoding: URLEncoding.default,
            headers: headers
        )
        .validate()
        .responseDecodable(of: ScanResponse.self) { [weak self] response in
            guard self != nil else { return }

            var uploadResult = URLUploadResult(statusMonitor: nil,
                                               uploadSuccess: nil,
                                               errorMessage: nil)

            switch response.result {
            case .success:
                uploadResult.uploadSuccess = true
                completion(uploadResult)
            case .failure(let error):
                log.error(error)
                uploadResult.uploadSuccess = false
                uploadResult.statusMonitor = .fail
                uploadResult.errorMessage = error.localizedDescription
                completion(uploadResult)
            }
        }
    }

    /// Given a string, return a URL that can be opened in external browser
    /// to view analysis report on VirusTotal website
    private func makeVtURL(from id: String) -> String {
        return "https://www.virustotal.com/gui/url/\(id)"
    }

    /// Given an inputURL, wait for 2 seconds and retry analyzeURL
    private func retryAnalyzeURL(inputURL: String,
                                 completion: @escaping(URLAnalysisResult) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.analyzeURL(inputURL: inputURL, completion: completion)
        }
    }
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

    enum CodingKeys: String, CodingKey {
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

    enum CodingKeys: String, CodingKey {
        case lastAnalysisStats = "last_analysis_stats"
        case lastAnalysisDate = "last_analysis_date"
        case lastFinalURL = "last_final_url"
        case reputation = "reputation"
    }
}

struct URLAnalysisStats: Codable {
    let malicious: Int
    let suspicious: Int
    let undetected: Int
    let harmless: Int
    let timeout: Int
}

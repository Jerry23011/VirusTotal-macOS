//
//  AnalyzeURLViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-07.
//

import Foundation
import SwiftUI

final class AnalyzeURLViewModel: ObservableObject {
    static let shared = AnalyzeURLViewModel()

    @Published var inputURL: String = ""
    @Published var vtURL: String = ""
    @Published var lastAnalysisTime: String = ""
    @Published var finalURL: String = ""
    @Published var finalURLHost: String = ""
    @Published var finalURLClean: String = ""
    @Published var errorMessage: String?
    @Published var communityScore: Int = 0
    @Published var analysisStats: URLAnalysisStats?
    @Published var statusMonitor: AnalysisStatus = .empty

    private var retryCount = 0
    private let maxRetries = 10

    /// Start the analysis of the URL
    func startURLAnalysis() {
        self.retryCount = 0 // Reset retry count
        self.statusMonitor = .loading
        analyzeURL()
    }

    /// Reanalyze the URL
    func requestReanalyze() {
        AnalyzeURL.shared.reanalyzeURL(inputURL: inputURL) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                if result.requestSuccess == true {
                    self.errorMessage = nil
                    self.startURLAnalysis()
                } else {
                    self.statusMonitor = .fail
                    self.errorMessage = result.errorMessage
                }
            }
        }
    }

    // MARK: Private

    /// Analyze the URL and handle retries if the result is not valid
    private func analyzeURL() {
        AnalyzeURL.shared.analyzeURL(inputURL: inputURL) { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.statusMonitor = result.statusMonitor ?? .loading
                self.errorMessage = result.errorMessage
                self.vtURL = result.vtURL ?? ""
                self.lastAnalysisTime = result.lastAnalysisDate ?? ""
                self.finalURL = result.finalURL ?? ""
                self.finalURLHost = self.findURLHost(result.finalURL ?? "")
                self.finalURLClean = self.removeURLQuery(result.finalURL ?? "") ?? ""
                self.communityScore = result.communityScore ?? 0
                self.analysisStats = result.lastAnalysisStats

                if let stats = result.lastAnalysisStats, self.isValidResponse(stats) {
                    self.statusMonitor = .success
                } else if self.retryCount < self.maxRetries {
                    self.retryCount += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        self.analyzeURL()
                    }
                } else {
                    log.error("Too many requests")
                    self.statusMonitor = .fail
                    self.errorMessage = "Request timeout."
                }
            }
        }
    }

    /// Given an URLAnalysisStats, return true if the sum of the flags is not 0, false otherwise
    private func isValidResponse(_ responses: URLAnalysisStats) -> Bool {
        return responses.allFlags.sum { $0 } != 0
    }

    /// Given a url, return the host of url
    private func findURLHost(_ url: String) -> String {
        let urlEncoded = URL(string: url)
        return urlEncoded?.host ?? ""
    }

    /// Given a URL string, return the URL with query removed
    private func removeURLQuery(_ url: String) -> String? {
        guard var urlEncoded = URLComponents(string: url) else {
            return nil
        }
        urlEncoded.query = nil // Remove the query string
        return urlEncoded.url?.absoluteString
    }
}

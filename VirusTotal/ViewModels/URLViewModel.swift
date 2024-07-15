//
//  URLViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-06-07.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class URLViewModel: ObservableObject {
    static let shared = URLViewModel()

    var inputURL: String = ""
    var vtURL: String = ""
    var lastAnalysisTime: String = ""
    var finalURL: String = ""
    var finalURLHost: String = ""
    var finalURLClean: String = ""
    var errorMessage: String?
    var communityScore: Int = 0
    var analysisStats: URLAnalysisStats?
    var statusMonitor: AnalysisStatus = .empty
    var categories: [String] = []

    private var retryCount = 0
    private let maxRetries = 10

    /// Start the analysis of the URL
    func startURLAnalysis() {
        Task {
            await analyzeURL()
        }
    }

    /// Reanalyze the URL
    func requestReanalyze() {
        Task {
            do {
                try await URLAnalysis.shared.reanalyzeURL(inputURL: inputURL)
                errorMessage = nil
                startURLAnalysis()
            } catch {
                statusMonitor = .fail
                errorMessage = error.localizedDescription
                log.error(error)
            }
        }
    }

    // MARK: Private

    /// Analyze the URL and handle retries if the result is not valid
    private func analyzeURL() async {
       retryCount = 0
       statusMonitor = .loading

       do {
           while retryCount < maxRetries {
               let result = try await URLAnalysis.shared.analyzeURL(inputURL: inputURL)
               updateUIWithResult(result)
               self.statusMonitor = .analyzing
               if isValidResponse(result.lastAnalysisStats) {
                   statusMonitor = .success
                   self.storeScanEntry()
                   return
               }

               retryCount += 1
               // Wait for 5 seconds
               try await Task.sleep(nanoseconds: 5_000_000_000)
           }
           let timeoutError = VTError.timeout("Request timeout: too many requests")
           log.error(timeoutError)
           throw timeoutError
       } catch {
           statusMonitor = .fail
           errorMessage = error.localizedDescription
           log.error(error)
       }
   }

    private func updateUIWithResult(_ result: URLAnalysisResult) {
        statusMonitor = result.statusMonitor ?? .loading
        errorMessage = result.errorMessage
        vtURL = result.vtURL ?? ""
        lastAnalysisTime = result.lastAnalysisDate ?? ""
        finalURL = result.finalURL ?? ""
        finalURLHost = findURLHost(result.finalURL ?? "")
        finalURLClean = removeURLQuery(result.finalURL ?? "") ?? ""
        communityScore = result.communityScore ?? 0
        analysisStats = result.lastAnalysisStats
        categories = result.categories ?? []
    }

    /// Given an URLAnalysisStats, return true if the sum of the flags is not 0, false otherwise
    private func isValidResponse(_ responses: URLAnalysisStats?) -> Bool {
        guard let responses = responses else { return false }
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

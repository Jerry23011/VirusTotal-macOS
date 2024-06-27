//
//  QuotaStatusViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import SwiftUI

@MainActor
final class QuotaStatusViewModel: ObservableObject {
    static let shared = QuotaStatusViewModel()

    @Published var statusSuccess: Bool?
    @Published var errorMessage: String?
    @Published var hourlyQuota: UserQuota?
    @Published var dailyQuota: UserQuota?
    @Published var monthlyQuota: UserQuota?

    func retryRequest() {
        Task {
            await performRequest()
        }
    }

    func performRequest() async {
        statusSuccess = nil
        do {
            let result = try await QuotaStatus.shared.performRequest()
            statusSuccess = result.statusSuccess
            errorMessage = result.errorMessage
            hourlyQuota = result.hourlyQuota
            dailyQuota = result.dailyQuota
            monthlyQuota = result.monthlyQuota
        } catch {
            statusSuccess = false
            errorMessage = error.localizedDescription
            log.error(error)
        }
    }
}

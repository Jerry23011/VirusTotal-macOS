//
//  QuotaStatusViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import SwiftUI

@MainActor
@Observable
final class QuotaStatusViewModel {
    static let shared = QuotaStatusViewModel()

    var statusSuccess: Bool?
    var errorMessage: String?
    var hourlyQuota: UserQuota?
    var dailyQuota: UserQuota?
    var monthlyQuota: UserQuota?

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

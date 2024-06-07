//
//  QuotaStatusViewModel.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-31.
//

import Foundation
import SwiftUI

final class QuotaStatusViewModel: ObservableObject {
    static let shared = QuotaStatusViewModel()

    @Published var statusSuccess: Bool?
    @Published var errorMessage: String?
    @Published var hourlyQuota: UserQuota?
    @Published var dailyQuota: UserQuota?
    @Published var monthlyQuota: UserQuota?

    /// Set statusSuccess as nil and perform request
    func retryRequest() {
        statusSuccess = nil
        performRequest()
    }

    /// Perform request
    func performRequest() {
        QuotaStatus.shared.performRequest { result in
            DispatchQueue.main.async {
                self.statusSuccess = result.statusSuccess
                self.errorMessage = result.errorMessage
                self.hourlyQuota = result.hourlyQuota
                self.dailyQuota = result.dailyQuota
                self.monthlyQuota = result.monthlyQuota
            }
        }
    }
}

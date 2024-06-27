//
//  QuotaStatus.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-20.
//

import Foundation
import Alamofire
import Defaults

actor QuotaStatus {
    static let shared = QuotaStatus()

    func performRequest() async throws -> QuotaResult {
        let quotas = try await fetchQuotas(apiKey: apiKey, userName: userName)

        var quotaResult = QuotaResult(
            statusSuccess: nil,
            errorMessage: nil,
            hourlyQuota: quotas.data.apiRequestsHourly.user,
            dailyQuota: quotas.data.apiRequestsDaily.user,
            monthlyQuota: quotas.data.apiRequestsMonthly.user
        )

        await storeQuotas(quotaResult)

        if await isQuotaExceeded(quotaResult) {
            quotaResult.statusSuccess = false
            quotaResult.errorMessage = maxQuotaMessage
        } else {
            quotaResult.statusSuccess = true
        }

        return quotaResult
    }

    // MARK: Private

    private var apiKey: String { Defaults[.apiKey] }
    private var userName: String { Defaults[.userName] }
    private let maxQuotaMessage: String = "Maximum quota exceeded"

    /// Given a QuotaResult, return true if hourly or daily quota used
    /// is equal or larger than hourly or daily quota allowed, return false otherwise
    private func isQuotaExceeded(_ result: QuotaResult) async -> Bool {
        guard let hourlyQuota = result.hourlyQuota,
              let dailyQuota = result.dailyQuota else {
            return false
        }
        return hourlyQuota.used >= hourlyQuota.allowed || dailyQuota.used >= dailyQuota.allowed
    }

    /// Given a QuotaResult, store hourly, daily, and monthly quotas in Defaults
    private func storeQuotas(_ result: QuotaResult) async {
        if let hourlyQuota = result.hourlyQuota {
            Defaults[.hourlyQuota] = hourlyQuota
        }
        if let dailyQuota = result.dailyQuota {
            Defaults[.dailyQuota] = dailyQuota
        }
        if let monthlyQuota = result.monthlyQuota {
            Defaults[.monthlyQuota] = monthlyQuota
        }
    }
}

// MARK: - Networking

private func fetchQuotas(apiKey: String, userName: String) async throws -> Quotas {
        let apiEndPoint = "https://www.virustotal.com/api/v3/users/\(userName)/overall_quotas"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "x-apikey": apiKey
        ]

        let quotas = try await AF.request(apiEndPoint, method: .get, headers: headers)
        .validate()
            .serializingDecodable(Quotas.self)
            .value
        return quotas
}

// MARK: - QuotaResult

struct QuotaResult {
    var statusSuccess: Bool?
    var errorMessage: String?
    var hourlyQuota: UserQuota?
    var dailyQuota: UserQuota?
    var monthlyQuota: UserQuota?
}

// MARK: Quota Response

struct Quotas: Decodable {
    let data: RequestData

    enum CodingKeys: String, CodingKey {
        case data
    }
}

struct RequestData: Decodable {
    let apiRequestsHourly: UserQuotaWrapper
    let apiRequestsDaily: UserQuotaWrapper
    let apiRequestsMonthly: UserQuotaWrapper

    enum CodingKeys: String, CodingKey {
        case apiRequestsHourly = "api_requests_hourly"
        case apiRequestsDaily = "api_requests_daily"
        case apiRequestsMonthly = "api_requests_monthly"
    }
}

struct UserQuotaWrapper: Decodable {
    let user: UserQuota

    enum CodingKeys: String, CodingKey {
        case user
    }
}

struct UserQuota: Decodable {
    let used: Int
    let allowed: Int

    enum CodingKeys: String, CodingKey {
        case used
        case allowed
    }
}

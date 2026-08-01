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
        var accountQuotas: AccountQuotas?
        var accountQuotasError: Error?

        do {
            accountQuotas = try await fetchUserQuotas(apiKey: apiKey)
        } catch where error.isCancellation {
            throw error
        } catch {
            accountQuotasError = error
        }

        let overallQuotas = try? await fetchQuotas(apiKey: apiKey, userName: userName)
        guard accountQuotas != nil || overallQuotas != nil else {
            throw accountQuotasError ?? QuotaError.unavailable
        }

        let hourlyQuota = accountQuotas?.apiRequestsHourly ?? overallQuotas?.data.apiRequestsHourly.effectiveQuota
        let dailyQuota = accountQuotas?.apiRequestsDaily ?? overallQuotas?.data.apiRequestsDaily.effectiveQuota
        let monthlyQuota = accountQuotas?.apiRequestsMonthly ?? overallQuotas?.data.apiRequestsMonthly.effectiveQuota

        var quotaResult = QuotaResult(
            statusSuccess: nil,
            errorMessage: nil,
            hourlyQuota: hourlyQuota,
            dailyQuota: dailyQuota,
            monthlyQuota: monthlyQuota
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

    private var apiKey: String { APIKeychain.apiKey }
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

private func fetchUserQuotas(apiKey: String) async throws -> AccountQuotas {
    let apiEndPoint = "https://www.virustotal.com/api/v3/users/\(apiKey)"
    let headers: HTTPHeaders = [
        "accept": "application/json",
        "x-apikey": apiKey
    ]

    let user = try await AF.request(apiEndPoint, method: .get, headers: headers)
        .validate()
        .serializingDecodable(VTUserResponse.self)
        .value

    return user.data.attributes.quotas
}

// MARK: - QuotaResult

struct QuotaResult {
    var statusSuccess: Bool?
    var errorMessage: String?
    var hourlyQuota: UserQuota?
    var dailyQuota: UserQuota?
    var monthlyQuota: UserQuota?
}

enum QuotaError: Error {
    case unavailable
}

// MARK: Quota Response

struct Quotas: Decodable {
    let data: RequestData

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct RequestData: Decodable {
    let apiRequestsHourly: UserQuotaWrapper
    let apiRequestsDaily: UserQuotaWrapper
    let apiRequestsMonthly: UserQuotaWrapper

    private enum CodingKeys: String, CodingKey {
        case apiRequestsHourly = "api_requests_hourly"
        case apiRequestsDaily = "api_requests_daily"
        case apiRequestsMonthly = "api_requests_monthly"
    }
}

struct VTUserResponse: Decodable {
    let data: VTUserData

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct VTUserData: Decodable {
    let attributes: VTUserAttributes

    private enum CodingKeys: String, CodingKey {
        case attributes
    }
}

struct VTUserAttributes: Decodable {
    let quotas: AccountQuotas

    private enum CodingKeys: String, CodingKey {
        case quotas
    }
}

struct AccountQuotas: Decodable {
    let apiRequestsHourly: UserQuota?
    let apiRequestsDaily: UserQuota?
    let apiRequestsMonthly: UserQuota?

    private enum CodingKeys: String, CodingKey {
        case apiRequestsHourly = "api_requests_hourly"
        case apiRequestsDaily = "api_requests_daily"
        case apiRequestsMonthly = "api_requests_monthly"
    }
}

struct UserQuotaWrapper: Decodable {
    let user: UserQuota?
    let group: UserQuota?

    var effectiveQuota: UserQuota? {
        user ?? group
    }

    private enum CodingKeys: String, CodingKey {
        case user
        case group
    }
}

struct UserQuota: Decodable {
    let used: Int
    let allowed: Int

    private enum CodingKeys: String, CodingKey {
        case used
        case allowed
    }
}

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
        } catch {
            accountQuotasError = error
        }

        // Avoid spending another API request when the user endpoint is complete.
        let overallQuotas = accountQuotas?.isComplete == true
            ? nil
            : try? await fetchQuotas(apiKey: apiKey, userName: userName)
        guard accountQuotas != nil || overallQuotas != nil else {
            throw accountQuotasError ?? QuotaError.unavailable
        }
        let quotaResult = try QuotaResult.resolve(account: accountQuotas, overall: overallQuotas)
        await storeQuotas(quotaResult)

        return quotaResult
    }

    // MARK: Private

    private var apiKey: String { APIKeychain.apiKey }
    private var userName: String { Defaults[.userName] }
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
    let userID = userName.isEmpty ? apiKey : userName
    let apiEndPoint = "https://www.virustotal.com/api/v3/users/\(userID)/overall_quotas"
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

//
//  QuotaStatus.swift
//  VirusTotal
//
//  Created by Jerry on 2024-05-20.
//

import Foundation
import Alamofire
import Defaults

final class QuotaStatus {

    static let shared = QuotaStatus()

    private var apiKey: String { Defaults[.apiKey] }
    private var userName: String { Defaults[.userName] }

    func performRequest(completion: @escaping (QuotaResult) -> Void) {
        let apiEndPoint = "https://www.virustotal.com/api/v3/users/\(userName)/overall_quotas"
        let headers: HTTPHeaders = [
            "accept": "application/json",
            "x-apikey": apiKey
        ]
        AF.request(apiEndPoint, method: .get, headers: headers)
            .validate()
            .responseDecodable(of: Quotas.self) { [weak self] response in
                guard let self = self else { return }

                var quotaResult = QuotaResult(statusSuccess: nil,
                                              errorMessage: nil,
                                              hourlyQuota: nil,
                                              dailyQuota: nil,
                                              monthlyQuota: nil)

                switch response.result {
                case .success(let quotas):
                    quotaResult.hourlyQuota = quotas.data.apiRequestsHourly.user
                    quotaResult.dailyQuota = quotas.data.apiRequestsDaily.user
                    quotaResult.monthlyQuota = quotas.data.apiRequestsMonthly.user
                    self.storeQuotas(quotaResult)
                    guard !isQuotaExceeded(quotaResult) else {
                        quotaResult.statusSuccess = false
                        quotaResult.errorMessage = maxQuotaMessage
                        completion(quotaResult)
                        return
                    }
                    quotaResult.statusSuccess = true
                    completion(quotaResult)

                case .failure(let error):
                    quotaResult.statusSuccess = false
                    quotaResult.errorMessage = error.localizedDescription
                    completion(quotaResult)
                }
            }
    }

    // MARK: - Private

    private let maxQuotaMessage: String = "Maximum quota exceeded"

    /// Given a QuotaResult, return true if hourly or daily quota used
    /// is equal or larger than hourly or daily quota allowed, return false otherwise
    private func isQuotaExceeded(_ result: QuotaResult) -> Bool {
        let hourlyQuota = result.hourlyQuota
        let dailyQuota = result.dailyQuota
        return hourlyQuota!.used >= hourlyQuota!.allowed || dailyQuota!.used >= dailyQuota!.allowed
    }

    /// Given a QuotaResult, store hourly, daily, and monthly quotas in Defaults
    private func storeQuotas(_ result: QuotaResult) {
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

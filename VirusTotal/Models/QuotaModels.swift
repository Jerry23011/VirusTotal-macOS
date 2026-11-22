import Foundation

// MARK: - QuotaResult

struct QuotaResult {
    var statusSuccess: Bool?
    var errorMessage: String?
    var hourlyQuota: UserQuota?
    var dailyQuota: UserQuota?
    var monthlyQuota: UserQuota?
}

enum QuotaError: LocalizedError {
    case unavailable
    var errorDescription: String? { String(localized: "quota.error.unavailable") }
}

// MARK: Quota Response

struct Quotas: Decodable {
    let data: RequestData

    private enum CodingKeys: String, CodingKey {
        case data
    }
}

struct RequestData: Decodable {
    let apiRequestsHourly: UserQuotaWrapper?
    let apiRequestsDaily: UserQuotaWrapper?
    let apiRequestsMonthly: UserQuotaWrapper?

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

extension AccountQuotas {
    var isComplete: Bool {
        apiRequestsHourly != nil && apiRequestsDaily != nil && apiRequestsMonthly != nil
    }
}

extension QuotaResult {
    static func resolve(account: AccountQuotas?, overall: Quotas?) throws -> QuotaResult {
        let hourly = account?.apiRequestsHourly ?? overall?.data.apiRequestsHourly?.effectiveQuota
        let daily = account?.apiRequestsDaily ?? overall?.data.apiRequestsDaily?.effectiveQuota
        let monthly = account?.apiRequestsMonthly ?? overall?.data.apiRequestsMonthly?.effectiveQuota
        let knownQuotas = [hourly, daily, monthly].compactMap { $0 }
        guard !knownQuotas.isEmpty else { throw QuotaError.unavailable }
        let exceeded = knownQuotas.contains { $0.used >= $0.allowed }
        return QuotaResult(statusSuccess: !exceeded,
                           errorMessage: exceeded ? String(localized: "Maximum quota exceeded") : nil,
                           hourlyQuota: hourly, dailyQuota: daily, monthlyQuota: monthly)
    }
}

import Foundation
import Testing
@testable import VirusTotal

@Suite("Quota decoding and fallback")
struct QuotaTests {
    @Test("Group quotas work when user quotas are null and periods are missing")
    func groupFallback() throws {
        let data = Data(#"{"data":{"api_requests_daily":{"user":null,"group":{"used":13,"allowed":1000}}}}"#.utf8)
        let overall = try JSONDecoder().decode(Quotas.self, from: data)
        let result = try QuotaResult.resolve(account: nil, overall: overall)
        #expect(result.dailyQuota?.used == 13)
        #expect(result.dailyQuota?.allowed == 1000)
        #expect(result.hourlyQuota == nil)
        #expect(result.statusSuccess == true)
    }

    @Test("User quotas win, and missing periods fall back independently")
    func partialAccountFallback() throws {
        let account = AccountQuotas(apiRequestsHourly: UserQuota(used: 2, allowed: 100),
                                    apiRequestsDaily: nil, apiRequestsMonthly: nil)
        let overall = Quotas(data: RequestData(apiRequestsHourly: nil,
            apiRequestsDaily: UserQuotaWrapper(user: UserQuota(used: 5, allowed: 500), group: nil),
            apiRequestsMonthly: nil))
        let result = try QuotaResult.resolve(account: account, overall: overall)
        #expect(result.hourlyQuota?.used == 2)
        #expect(result.dailyQuota?.used == 5)
        #expect(!account.isComplete)
    }

    @Test("Empty quota responses report unavailable instead of successful 0/0")
    func emptyResponse() throws {
        let overall = try JSONDecoder().decode(Quotas.self, from: Data(#"{"data":{}}"#.utf8))
        #expect(throws: QuotaError.self) {
            try QuotaResult.resolve(account: nil, overall: overall)
        }
    }

    @Test("A known exhausted quota is detected even when another period is absent")
    func partialQuotaExhaustion() throws {
        let account = AccountQuotas(apiRequestsHourly: nil,
            apiRequestsDaily: UserQuota(used: 501, allowed: 500), apiRequestsMonthly: nil)
        let result = try QuotaResult.resolve(account: account, overall: nil)
        #expect(result.statusSuccess == false)
        #expect(result.errorMessage != nil)
    }
}

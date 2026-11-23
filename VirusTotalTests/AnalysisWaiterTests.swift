import Foundation
import Testing
@testable import VirusTotal

@Suite("Queued analysis polling")
struct AnalysisWaiterTests {
    private actor Statuses {
        var values: [String?]
        private(set) var calls = 0
        init(_ values: [String?]) { self.values = values }
        func next() -> String? {
            calls += 1
            return values.isEmpty ? nil : values.removeFirst()
        }
    }

    @Test("Queued and running analyses wait until completed")
    func completion() async throws {
        let statuses = Statuses(["queued", "in-progress", "completed"])
        try await AnalysisWaiter.waitForCompletion(fetchStatus: { await statuses.next() }, pause: {})
        #expect(await statuses.calls == 3)
    }

    @Test("Missing status times out within the polling budget")
    func timeout() async {
        let statuses = Statuses([])
        await #expect(throws: VTError.self) {
            try await AnalysisWaiter.waitForCompletion(fetchStatus: { await statuses.next() }, pause: {})
        }
        #expect(await statuses.calls == ScanPolicy.maxPollingAttempts + 1)
    }

    @Test("API errors are preserved instead of becoming an endless wait")
    func failure() async {
        await #expect(throws: URLError.self) {
            try await AnalysisWaiter.waitForCompletion(fetchStatus: { throw URLError(.userAuthenticationRequired) }, pause: {})
        }
    }

    @Test("Cancellation stops polling before the next request")
    func cancellation() async {
        let task = Task {
            try await AnalysisWaiter.waitForCompletion(fetchStatus: { "queued" }, pause: { throw CancellationError() })
        }
        await #expect(throws: CancellationError.self) { try await task.value }
    }
}

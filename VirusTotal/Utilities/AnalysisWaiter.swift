import Foundation

enum AnalysisWaiter {
    static func waitForCompletion(
        fetchStatus: @Sendable () async throws -> String?,
        pause: @Sendable () async throws -> Void = { try await Task.sleep(for: ScanPolicy.pollingInterval) }
    ) async throws {
        for attempt in 0...ScanPolicy.maxPollingAttempts {
            try Task.checkCancellation()
            let status = try await fetchStatus()
            try Task.checkCancellation()
            switch ScanPolicy.analysisPollDecision(status: status, attempt: attempt) {
            case .finished: return
            case .timedOut: throw VTError.timeout(String(localized: "error.analysis.timeout"))
            case .keepWaiting: try await pause()
            }
        }
    }
}

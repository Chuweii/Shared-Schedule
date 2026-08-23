import Foundation
import OSLog

private let log = Logger(
    subsystem: "com.Kyoi.Shared-Schedule", category: "CrashReporting"
)

protocol RecordCrashReportsUseCaseProtocol: Sendable {
    func recordCrashReports(_ reports: [CrashReport]) async
}

/// Persists incoming crash diagnostics to the local queue. Best-effort:
/// a failing store must never surface an error into the running app.
nonisolated struct RecordCrashReportsUseCase: RecordCrashReportsUseCaseProtocol {
    let store: any CrashReportStoreProtocol

    init(store: any CrashReportStoreProtocol) {
        self.store = store
    }

    func recordCrashReports(_ reports: [CrashReport]) async {
        for report in reports {
            do {
                try await store.save(report)
                log.notice("crash diagnostic recorded: \(report.fileName(), privacy: .public)")
            } catch {
                log.error("crash diagnostic dropped: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

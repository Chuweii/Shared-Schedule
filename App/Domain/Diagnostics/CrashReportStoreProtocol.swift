import Foundation

nonisolated enum CrashReportStoreError: Error, Equatable, Sendable {
    case writeFailed
    case readFailed
}

/// Local queue for crash reports awaiting upload. Deduplicates by
/// `contentHash` and retains only the newest reports.
protocol CrashReportStoreProtocol: Sendable {
    func save(_ report: CrashReport) async throws(CrashReportStoreError)
    func listAll() async throws(CrashReportStoreError) -> [CrashReport]
    func delete(id: UUID) async throws(CrashReportStoreError)
}

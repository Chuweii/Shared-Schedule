import Foundation
@testable import Shared_Schedule

final class FakeCrashReportStore: CrashReportStoreProtocol, @unchecked Sendable {
    var reports: [CrashReport] = []
    var errorToThrow: CrashReportStoreError?

    func save(_ report: CrashReport) async throws(CrashReportStoreError) {
        if let errorToThrow { throw errorToThrow }
        reports.append(report)
    }

    func listAll() async throws(CrashReportStoreError) -> [CrashReport] {
        if let errorToThrow { throw errorToThrow }
        return reports
    }

    func delete(id: UUID) async throws(CrashReportStoreError) {
        if let errorToThrow { throw errorToThrow }
        reports.removeAll { $0.id == id }
    }
}

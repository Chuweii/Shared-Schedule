import Foundation
@testable import Shared_Schedule

final class FakeCrashReportUploader: CrashReportUploaderProtocol, @unchecked Sendable {
    var uploaded: [CrashReport] = []
    /// Report ids that should fail with the paired error.
    var errorsByID: [UUID: CrashReportUploadError] = [:]

    func upload(_ report: CrashReport) async throws(CrashReportUploadError) {
        if let error = errorsByID[report.id] { throw error }
        uploaded.append(report)
    }
}

nonisolated enum CrashReportUploadError: Error, Equatable, Sendable {
    case notAuthenticated
    case network
    case persistenceFailure
}

protocol CrashReportUploaderProtocol: Sendable {
    func upload(_ report: CrashReport) async throws(CrashReportUploadError)
}

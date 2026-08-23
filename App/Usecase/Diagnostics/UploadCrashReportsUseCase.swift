import Foundation
import OSLog

private let log = Logger(
    subsystem: "com.Kyoi.Shared-Schedule", category: "CrashReporting"
)

protocol UploadCrashReportsUseCaseProtocol: Sendable {
    func uploadPendingReports() async
}

/// Drains the local crash report queue to the backend. A report is
/// deleted locally only after its upload succeeds; failures keep the
/// report queued for the next authenticated launch. Best-effort — never
/// throws into the caller.
nonisolated struct UploadCrashReportsUseCase: UploadCrashReportsUseCaseProtocol {
    let store: any CrashReportStoreProtocol
    let uploader: any CrashReportUploaderProtocol

    init(
        store: any CrashReportStoreProtocol,
        uploader: any CrashReportUploaderProtocol
    ) {
        self.store = store
        self.uploader = uploader
    }

    func uploadPendingReports() async {
        let pending: [CrashReport]
        do {
            pending = try await store.listAll()
        } catch {
            log.error("crash queue unreadable: \(String(describing: error), privacy: .public)")
            return
        }
        for report in pending {
            do {
                try await uploader.upload(report)
                try await store.delete(id: report.id)
                log.notice("crash report uploaded: \(report.fileName(), privacy: .public)")
            } catch {
                log.error("crash report upload failed, kept queued: \(String(describing: error), privacy: .public)")
            }
        }
    }
}

import Foundation

/// Composition glue instantiated once from the App struct. Owns the
/// single shared file store so the MetricKit subscriber (writer) and the
/// upload path (drainer) never race on separate actor instances.
nonisolated final class CrashReportingBootstrap {
    let uploadUseCase: UploadCrashReportsUseCase
    private let subscriber: MetricKitCrashSubscriber

    init() {
        let store = FileCrashReportStore(
            directory: URL.applicationSupportDirectory
                .appending(path: "CrashReports")
        )
        self.uploadUseCase = UploadCrashReportsUseCase(
            store: store,
            uploader: SupabaseCrashReportUploader()
        )
        self.subscriber = MetricKitCrashSubscriber(
            recordUseCase: RecordCrashReportsUseCase(store: store)
        )
    }
}

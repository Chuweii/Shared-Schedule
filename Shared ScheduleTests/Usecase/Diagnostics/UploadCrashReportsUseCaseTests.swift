import Foundation
import Testing
@testable import Shared_Schedule

struct UploadCrashReportsUseCaseTests {
    @Test("Given two pending reports, when uploading succeeds, then both are uploaded and deleted locally")
    func uploadPendingReports_success_deletesLocal() async {
        // Given
        let store = FakeCrashReportStore()
        let uploader = FakeCrashReportUploader()
        store.reports = [
            CrashReport.sample(jsonRepresentation: Data(#"{"crash":1}"#.utf8)),
            CrashReport.sample(jsonRepresentation: Data(#"{"crash":2}"#.utf8)),
        ]
        let useCase = UploadCrashReportsUseCase(store: store, uploader: uploader)

        // When
        await useCase.uploadPendingReports()

        // Then
        #expect(uploader.uploaded.count == 2)
        #expect(store.reports.isEmpty)
    }

    @Test("Given an upload that fails for one report, when uploading, then the failed report is kept locally")
    func uploadPendingReports_partialFailure_keepsFailed() async {
        // Given
        let store = FakeCrashReportStore()
        let uploader = FakeCrashReportUploader()
        let ok = CrashReport.sample(jsonRepresentation: Data(#"{"crash":1}"#.utf8))
        let failing = CrashReport.sample(jsonRepresentation: Data(#"{"crash":2}"#.utf8))
        store.reports = [ok, failing]
        uploader.errorsByID = [failing.id: .network]
        let useCase = UploadCrashReportsUseCase(store: store, uploader: uploader)

        // When
        await useCase.uploadPendingReports()

        // Then
        #expect(uploader.uploaded == [ok])
        #expect(store.reports == [failing])
    }

    @Test("Given an empty queue, when uploading, then the uploader is not called")
    func uploadPendingReports_emptyQueue_uploaderNotCalled() async {
        // Given
        let store = FakeCrashReportStore()
        let uploader = FakeCrashReportUploader()
        let useCase = UploadCrashReportsUseCase(store: store, uploader: uploader)

        // When
        await useCase.uploadPendingReports()

        // Then
        #expect(uploader.uploaded.isEmpty)
    }
}

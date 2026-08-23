import Foundation
import Testing
@testable import Shared_Schedule

struct RecordCrashReportsUseCaseTests {
    @Test("Given two new reports, when recorded, then both are saved to the store")
    func recordCrashReports_twoReports_bothSaved() async {
        // Given
        let store = FakeCrashReportStore()
        let useCase = RecordCrashReportsUseCase(store: store)
        let first = CrashReport.sample(jsonRepresentation: Data(#"{"crash":1}"#.utf8))
        let second = CrashReport.sample(jsonRepresentation: Data(#"{"crash":2}"#.utf8))

        // When
        await useCase.recordCrashReports([first, second])

        // Then
        #expect(store.reports == [first, second])
    }

    @Test("Given a store that fails, when recording, then no error escapes")
    func recordCrashReports_storeFailure_doesNotThrow() async {
        // Given
        let store = FakeCrashReportStore()
        store.errorToThrow = .writeFailed
        let useCase = RecordCrashReportsUseCase(store: store)

        // When
        await useCase.recordCrashReports([CrashReport.sample()])

        // Then
        #expect(store.reports.isEmpty)
    }
}

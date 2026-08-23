import Foundation
import Testing
@testable import Shared_Schedule

struct CrashReportTests {
    @Test("Given a crash report, when the file name is derived, then it contains the end timestamp and id")
    func fileName_containsTimestampAndID() {
        // Given
        let id = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let end = Date(timeIntervalSince1970: 1_700_000_000)
        let report = CrashReport.sample(id: id, timeStampEnd: end)

        // When
        let name = report.fileName()

        // Then
        #expect(name.hasPrefix("crash-"))
        #expect(name.hasSuffix(".json"))
        #expect(name.contains("2023-11-14T22:13:20Z"))
        #expect(name.contains(id.uuidString))
    }

    @Test("Given two reports with identical payloads, when content hashes are compared, then they are equal")
    func contentHash_identicalPayloads_areEqual() {
        // Given
        let payload = Data(#"{"crash":"stack"}"#.utf8)
        let first = CrashReport.sample(id: UUID(), jsonRepresentation: payload)
        let second = CrashReport.sample(id: UUID(), jsonRepresentation: payload)
        let different = CrashReport.sample(
            id: UUID(),
            jsonRepresentation: Data(#"{"crash":"other"}"#.utf8)
        )

        // When / Then
        #expect(first.contentHash == second.contentHash)
        #expect(first.contentHash != different.contentHash)
    }
}

extension CrashReport {
    static func sample(
        id: UUID = UUID(),
        timeStampEnd: Date = Date(timeIntervalSince1970: 1_700_000_000),
        appVersion: String = "1.0",
        jsonRepresentation: Data = Data(#"{"crash":"sample"}"#.utf8)
    ) -> CrashReport {
        CrashReport(
            id: id,
            timeStampBegin: timeStampEnd.addingTimeInterval(-60),
            timeStampEnd: timeStampEnd,
            appVersion: appVersion,
            osVersion: "26.0",
            jsonRepresentation: jsonRepresentation
        )
    }
}

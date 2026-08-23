import Foundation
import Testing
@testable import Shared_Schedule

struct FileCrashReportStoreTests {
    private func makeStore() -> (FileCrashReportStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("crash-store-tests-\(UUID().uuidString)")
        return (FileCrashReportStore(directory: directory), directory)
    }

    @Test("Given an empty store, when a report is saved, then listAll returns it and a JSON file exists")
    func save_emptyStore_persistsFile() async throws {
        // Given
        let (store, directory) = makeStore()
        let report = CrashReport.sample()

        // When
        try await store.save(report)

        // Then
        let listed = try await store.listAll()
        #expect(listed == [report])
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files == [report.fileName()])
    }

    @Test("Given a saved report, when the same payload is saved again, then only one file exists")
    func save_duplicatePayload_isDeduped() async throws {
        // Given
        let (store, directory) = makeStore()
        let payload = Data(#"{"crash":"same"}"#.utf8)
        try await store.save(CrashReport.sample(id: UUID(), jsonRepresentation: payload))

        // When
        try await store.save(CrashReport.sample(id: UUID(), jsonRepresentation: payload))

        // Then
        let listed = try await store.listAll()
        #expect(listed.count == 1)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.count == 1)
    }

    @Test("Given 20 saved reports, when a 21st is saved, then the oldest is pruned")
    func save_beyondRetentionLimit_prunesOldest() async throws {
        // Given
        let (store, _) = makeStore()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        for index in 0..<20 {
            try await store.save(CrashReport.sample(
                timeStampEnd: base.addingTimeInterval(Double(index) * 60),
                jsonRepresentation: Data("{\"crash\":\(index)}".utf8)
            ))
        }
        let newest = CrashReport.sample(
            timeStampEnd: base.addingTimeInterval(20 * 60),
            jsonRepresentation: Data(#"{"crash":20}"#.utf8)
        )

        // When
        try await store.save(newest)

        // Then
        let listed = try await store.listAll()
        #expect(listed.count == 20)
        #expect(listed.contains(newest))
        #expect(!listed.contains { $0.timeStampEnd == base })
    }

    @Test("Given a report stored under a non-canonical file name, when it is deleted by id, then the file is removed")
    func delete_nonCanonicalFileName_stillRemovesFile() async throws {
        // Given
        let (store, directory) = makeStore()
        let report = CrashReport.sample()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(report)
            .write(to: directory.appendingPathComponent("crash-renamed-by-hand.json"))

        // When
        try await store.delete(id: report.id)

        // Then
        let listed = try await store.listAll()
        #expect(listed.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(files.isEmpty)
    }

    @Test("Given a corrupt file in the directory, when listAll runs, then the corrupt file is skipped without throwing")
    func listAll_corruptFile_isSkipped() async throws {
        // Given
        let (store, directory) = makeStore()
        let report = CrashReport.sample()
        try await store.save(report)
        try Data("not json".utf8).write(to: directory.appendingPathComponent("crash-garbage.json"))

        // When
        let listed = try await store.listAll()

        // Then
        #expect(listed == [report])
    }
}

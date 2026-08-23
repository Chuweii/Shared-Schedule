import Foundation

/// JSON-file-backed crash report queue under an injected directory.
/// Deduplicates by `contentHash` and keeps only the newest
/// `retentionLimit` reports.
actor FileCrashReportStore: CrashReportStoreProtocol {
    private let directory: URL
    private let retentionLimit: Int

    init(directory: URL, retentionLimit: Int = 20) {
        self.directory = directory
        self.retentionLimit = retentionLimit
    }

    func save(_ report: CrashReport) throws(CrashReportStoreError) {
        let existing = try listAll()
        guard !existing.contains(where: { $0.contentHash == report.contentHash }) else {
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(report)
            try data.write(to: directory.appendingPathComponent(report.fileName()))
        } catch {
            throw .writeFailed
        }
        let all = (existing + [report]).sorted { $0.timeStampEnd < $1.timeStampEnd }
        for stale in all.dropLast(retentionLimit) {
            try delete(id: stale.id)
        }
    }

    func listAll() throws(CrashReportStoreError) -> [CrashReport] {
        let fileURLs: [URL]
        do {
            fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            )
        } catch CocoaError.fileReadNoSuchFile {
            return []
        } catch {
            throw .readFailed
        }
        // Corrupt files are skipped, not fatal: one bad file must never
        // wedge the whole queue.
        return fileURLs
            .compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? JSONDecoder().decode(CrashReport.self, from: data)
            }
            .sorted { $0.timeStampEnd < $1.timeStampEnd }
    }

    func delete(id: UUID) throws(CrashReportStoreError) {
        let fileURLs: [URL]
        do {
            fileURLs = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: nil
            )
        } catch CocoaError.fileReadNoSuchFile {
            return
        } catch {
            throw .readFailed
        }
        // Locate by decoded id, not by re-deriving the file name: a file
        // renamed by anything outside this store must not become an
        // undeletable report that re-uploads on every launch.
        for url in fileURLs {
            guard let data = try? Data(contentsOf: url),
                  let report = try? JSONDecoder().decode(CrashReport.self, from: data),
                  report.id == id else { continue }
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                throw .writeFailed
            }
        }
    }
}

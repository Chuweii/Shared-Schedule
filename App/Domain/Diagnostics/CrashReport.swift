import Foundation

/// A crash diagnostic converted from MetricKit at the Infrastructure
/// boundary. MetricKit payload types have no public initializers, so this
/// owned value is the earliest testable shape in the pipeline.
nonisolated struct CrashReport: Equatable, Sendable, Codable {
    let id: UUID
    let timeStampBegin: Date
    let timeStampEnd: Date
    let appVersion: String
    let osVersion: String
    /// Raw `MXCrashDiagnostic.jsonRepresentation()` bytes.
    let jsonRepresentation: Data

    /// Stable FNV-1a digest of the payload; dedupes identical diagnostics
    /// the OS may deliver more than once.
    var contentHash: String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in jsonRepresentation {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return String(format: "%016llx", hash)
    }

    func fileName() -> String {
        "crash-\(timeStampEnd.formatted(.iso8601))-\(id.uuidString).json"
    }
}

import Foundation

nonisolated struct AvailabilityWindowID: Hashable, Sendable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

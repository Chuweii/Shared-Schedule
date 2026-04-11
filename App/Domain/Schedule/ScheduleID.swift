import Foundation

nonisolated struct ScheduleID: Hashable, Sendable {
    let rawValue: UUID

    init(_ rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

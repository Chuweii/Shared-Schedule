import Foundation

nonisolated struct AvailabilityWindow: Hashable, Sendable {
    let id: AvailabilityWindowID
    let start: Date
    let end: Date

    var duration: TimeInterval {
        end.timeIntervalSince(start)
    }
}

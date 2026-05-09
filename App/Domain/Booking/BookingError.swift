import Foundation

nonisolated enum BookingError: Error, Equatable, Sendable {
    case invalidRange
    case invalidDuration
    case durationMismatch
}

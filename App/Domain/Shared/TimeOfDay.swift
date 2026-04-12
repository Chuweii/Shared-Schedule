import Foundation

nonisolated enum TimeOfDayError: Error, Equatable, Sendable {
    case invalidHour
    case invalidMinute
}

nonisolated struct TimeOfDay: Hashable, Comparable, Sendable {
    let hour: Int
    let minute: Int

    init(hour: Int, minute: Int) throws(TimeOfDayError) {
        guard (0...23).contains(hour) else { throw .invalidHour }
        guard (0...59).contains(minute) else { throw .invalidMinute }
        self.hour = hour
        self.minute = minute
    }

    var totalMinutes: Int { hour * 60 + minute }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.totalMinutes < rhs.totalMinutes
    }
}

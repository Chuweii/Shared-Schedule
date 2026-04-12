import Foundation

nonisolated struct Schedule: Sendable {
    static let defaultMinWindowDuration: TimeInterval = 3600

    let id: ScheduleID
    let ownerID: UserID
    let title: String
    let minWindowDuration: TimeInterval
    private(set) var windows: [AvailabilityWindow]
    private(set) var rules: [AvailabilityRule]

    init(
        id: ScheduleID = ScheduleID(),
        ownerID: UserID,
        title: String,
        minWindowDuration: TimeInterval = Schedule.defaultMinWindowDuration
    ) {
        self.id = id
        self.ownerID = ownerID
        self.title = title
        self.minWindowDuration = minWindowDuration
        self.windows = []
        self.rules = []
    }

    mutating func addWindow(
        id: AvailabilityWindowID = AvailabilityWindowID(),
        start: Date,
        end: Date
    ) throws(ScheduleError) {
        guard end > start else {
            throw .invalidRange
        }

        let duration = end.timeIntervalSince(start)
        guard duration >= minWindowDuration else {
            throw .belowMinimumDuration
        }

        for existing in windows {
            if start < existing.end && existing.start < end {
                throw .overlapping
            }
        }

        windows.append(AvailabilityWindow(id: id, start: start, end: end))
    }

    mutating func removeWindow(id: AvailabilityWindowID) {
        windows.removeAll { $0.id == id }
    }

    // MARK: - Availability Rules

    mutating func addRule(
        id: AvailabilityRuleID = AvailabilityRuleID(),
        weekday: Weekday,
        startTime: TimeOfDay,
        endTime: TimeOfDay
    ) throws(ScheduleError) {
        guard startTime < endTime else {
            throw .invalidRange
        }

        let durationMinutes = endTime.totalMinutes - startTime.totalMinutes
        guard Double(durationMinutes * 60) >= minWindowDuration else {
            throw .ruleTooShort
        }

        guard !rules.contains(where: { $0.weekday == weekday }) else {
            throw .ruleOverlapping
        }

        rules.append(AvailabilityRule(
            id: id, weekday: weekday,
            startTime: startTime, endTime: endTime
        ))
    }

    mutating func removeRule(id: AvailabilityRuleID) {
        rules.removeAll { $0.id == id }
    }

    func rulesFor(weekday: Weekday) -> [AvailabilityRule] {
        rules.filter { $0.weekday == weekday }
    }
}

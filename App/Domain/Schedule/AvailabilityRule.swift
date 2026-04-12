nonisolated struct AvailabilityRule: Hashable, Sendable {
    let id: AvailabilityRuleID
    let weekday: Weekday
    let startTime: TimeOfDay
    let endTime: TimeOfDay

    var durationMinutes: Int {
        endTime.totalMinutes - startTime.totalMinutes
    }
}

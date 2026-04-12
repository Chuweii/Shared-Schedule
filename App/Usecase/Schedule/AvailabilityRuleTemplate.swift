nonisolated struct AvailabilityRuleTemplate: Sendable {
    let weekdays: Set<Weekday>
    let startTime: TimeOfDay
    let endTime: TimeOfDay
}

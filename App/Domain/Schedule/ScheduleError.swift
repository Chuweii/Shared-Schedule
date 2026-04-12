nonisolated enum ScheduleError: Error, Equatable, Sendable {
    case invalidRange
    case belowMinimumDuration
    case overlapping
    case ruleOverlapping
    case ruleTooShort
}

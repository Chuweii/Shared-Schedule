nonisolated enum ScheduleMutationError: Error, Equatable, Sendable {
    case notOwner
    case scheduleNotFound
    case scheduleError(ScheduleError)
}

nonisolated enum CreateScheduleError: Error, Equatable, Sendable {
    case blankTitle
    case noWeekdaysSelected
    case repositoryFailure
}

protocol RemoveAvailabilityWindowUseCaseProtocol: Sendable {
    func removeWindow(
        _ windowID: AvailabilityWindowID,
        from scheduleID: ScheduleID
    ) async throws(ScheduleMutationError) -> Schedule
}

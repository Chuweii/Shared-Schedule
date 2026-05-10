protocol ListOthersBookingsUseCaseProtocol: Sendable {
    func listOthersBookings(scheduleID: ScheduleID)
        async throws(ListOthersBookingsError) -> [BookedSlot]
}

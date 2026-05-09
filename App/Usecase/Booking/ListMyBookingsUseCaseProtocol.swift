protocol ListMyBookingsUseCaseProtocol: Sendable {
    func listMyBookings(scheduleID: ScheduleID)
        async throws(ListMyBookingsError) -> [Booking]
}

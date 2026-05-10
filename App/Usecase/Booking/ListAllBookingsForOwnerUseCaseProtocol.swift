protocol ListAllBookingsForOwnerUseCaseProtocol: Sendable {
    func listAllBookingsForOwner(scheduleID: ScheduleID)
        async throws(ListAllBookingsForOwnerError) -> [OwnerBooking]
}

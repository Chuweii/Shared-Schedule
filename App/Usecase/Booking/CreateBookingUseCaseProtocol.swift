protocol CreateBookingUseCaseProtocol: Sendable {
    func createBooking(scheduleID: ScheduleID, slot: ComputedSlot)
        async throws(CreateBookingError) -> Booking
}

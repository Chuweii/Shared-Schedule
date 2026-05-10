/// Member-only fetch of other students' bookings on a schedule (Slice 2).
/// Pure passthrough to the repository — server-side
/// `get_bookings_visible_to_member` RPC is the source of truth for
/// membership and PII filtering. No client-side preflight.
nonisolated struct ListOthersBookingsUseCase: ListOthersBookingsUseCaseProtocol {
    let bookingRepository: any BookingRepositoryProtocol

    init(bookingRepository: any BookingRepositoryProtocol) {
        self.bookingRepository = bookingRepository
    }

    func listOthersBookings(scheduleID: ScheduleID)
        async throws(ListOthersBookingsError) -> [BookedSlot]
    {
        try await bookingRepository.fetchOthersBookings(scheduleID: scheduleID)
    }
}

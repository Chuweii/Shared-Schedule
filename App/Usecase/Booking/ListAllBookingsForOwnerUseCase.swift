nonisolated struct ListAllBookingsForOwnerUseCase: ListAllBookingsForOwnerUseCaseProtocol {
    let bookingRepository: any BookingRepositoryProtocol

    init(bookingRepository: any BookingRepositoryProtocol) {
        self.bookingRepository = bookingRepository
    }

    func listAllBookingsForOwner(scheduleID: ScheduleID)
        async throws(ListAllBookingsForOwnerError) -> [OwnerBooking]
    {
        try await bookingRepository.fetchAllForOwner(scheduleID: scheduleID)
    }
}

nonisolated struct ListMyBookingsUseCase: ListMyBookingsUseCaseProtocol {
    let bookingRepository: any BookingRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    init(
        bookingRepository: any BookingRepositoryProtocol,
        currentUserProvider: any CurrentUserProviderProtocol
    ) {
        self.bookingRepository = bookingRepository
        self.currentUserProvider = currentUserProvider
    }

    func listMyBookings(scheduleID: ScheduleID)
        async throws(ListMyBookingsError) -> [Booking]
    {
        do {
            return try await bookingRepository.fetchAll(
                scheduleID: scheduleID,
                studentID: currentUserProvider.currentUser.id
            )
        } catch {
            throw .persistenceFailure
        }
    }
}

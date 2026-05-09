nonisolated struct CancelBookingUseCase: CancelBookingUseCaseProtocol {
    let bookingRepository: any BookingRepositoryProtocol

    init(bookingRepository: any BookingRepositoryProtocol) {
        self.bookingRepository = bookingRepository
    }

    func cancelBooking(_ bookingID: BookingID) async throws(CancelBookingError) {
        try await bookingRepository.cancel(id: bookingID)
    }
}

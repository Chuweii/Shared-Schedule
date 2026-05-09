protocol CancelBookingUseCaseProtocol: Sendable {
    func cancelBooking(_ bookingID: BookingID) async throws(CancelBookingError)
}

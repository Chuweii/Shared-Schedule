/// Outcomes of cancelling a booking. Lives in Domain alongside
/// `CreateBookingError` so the Repository protocol stays
/// Infrastructure-agnostic.
nonisolated enum CancelBookingError: Error, Equatable, Sendable {
    case bookingNotFound
    case notOwner
    case slotAlreadyStarted
    case persistenceFailure
}

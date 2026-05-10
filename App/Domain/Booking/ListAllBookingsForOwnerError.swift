/// Outcomes of `BookingRepositoryProtocol.fetchAllForOwner`. Lives in
/// Domain (alongside CreateBookingError / CancelBookingError) so the
/// repo protocol stays Infrastructure-agnostic.
nonisolated enum ListAllBookingsForOwnerError: Error, Equatable, Sendable {
    case notOwner
    case persistenceFailure
}

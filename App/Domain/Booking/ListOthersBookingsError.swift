/// Outcomes of `BookingRepositoryProtocol.fetchOthersBookings` (Slice 2).
/// Mirrors `ListAllBookingsForOwnerError` shape with the role flipped:
/// member-only fetch path that surfaces sanitized `BookedSlot` rows.
nonisolated enum ListOthersBookingsError: Error, Equatable, Sendable {
    case notMember
    case persistenceFailure
}

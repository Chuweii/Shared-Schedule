/// Outcomes of creating a booking. Lives in Domain so
/// `BookingRepositoryProtocol.create` can throw it without leaking
/// Infrastructure types up to Usecase / Presentation. Mirrors
/// `InvitationRedemptionError`'s placement.
nonisolated enum CreateBookingError: Error, Equatable, Sendable {
    case scheduleNotFound
    case notMember
    case ownerCannotBook
    case slotNotInSchedule
    case slotInPast
    case slotTaken
    case persistenceFailure
}

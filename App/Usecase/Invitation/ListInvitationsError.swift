nonisolated enum ListInvitationsError: Error, Equatable, Sendable {
    case scheduleNotFound
    case notOwner
    case persistenceFailure
}

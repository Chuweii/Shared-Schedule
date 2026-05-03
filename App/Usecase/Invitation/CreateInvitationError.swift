nonisolated enum CreateInvitationError: Error, Equatable, Sendable {
    case scheduleNotFound
    case notOwner
    case persistenceFailure
}

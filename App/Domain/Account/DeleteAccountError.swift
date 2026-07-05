/// Outcomes for `AccountRepository.deleteAccount`. Account deletion is a
/// stateless command, so there is no `Account` entity / invariant — this
/// enum captures only the repository failure modes, mirroring the typed
/// throws used elsewhere (e.g. `CancelBookingError`).
nonisolated enum DeleteAccountError: Error, Equatable, Sendable {
    /// RPC `AUTH_REQUIRED` — no session. Defensive; the login gate should
    /// prevent reaching here.
    case notAuthenticated
    case network
    case persistenceFailure
}

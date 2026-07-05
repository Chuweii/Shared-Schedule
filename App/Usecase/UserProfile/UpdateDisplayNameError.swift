/// Outcomes for `UpdateDisplayNameUseCase`. Mirrors the client-preflight
/// + repository-passthrough shape of `CompleteSignUpError`.
nonisolated enum UpdateDisplayNameError: Error, Equatable, Sendable {
    /// Empty after trim, or longer than 50 chars (client preflight, or
    /// server-side length rejection).
    case invalidDisplayName
    case persistenceFailure
}

/// Outcomes of `SignInUseCase.signIn`.
nonisolated enum SignInError: Error, Equatable, Sendable {
    /// Account exists but email was never verified — UI should offer
    /// a "resend verification code" affordance.
    case emailNotConfirmed
    case invalidCredentials
    case network
    case generic
}

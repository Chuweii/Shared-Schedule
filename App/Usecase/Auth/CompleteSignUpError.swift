/// Outcomes of `CompleteSignUpUseCase.completeSignUp`. Combines
/// pre-flight validation, Supabase Auth signup outcomes, and the
/// downstream `user_profiles` creation result.
nonisolated enum CompleteSignUpError: Error, Equatable, Sendable {
    case invalidEmail
    case invalidPassword           // length < 6
    case invalidDisplayName
    case userAlreadyExists
    case weakPassword
    /// Auth signup succeeded but profile creation failed. The user is
    /// in a "logged in but no profile" state — UI should ask them to
    /// retry (Slice A MVP simplifies this to a "please restart" prompt).
    case partialFailure
    case network
    case generic
}

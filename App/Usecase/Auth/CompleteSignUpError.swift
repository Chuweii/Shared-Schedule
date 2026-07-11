/// Outcomes of `CompleteSignUpUseCase.completeSignUp`: pre-flight
/// validation plus Supabase Auth signup outcomes. (Profile creation
/// moved to `VerifyEmailOTPUseCase` in Slice C, so the old
/// `.partialFailure` state can no longer occur at sign-up time.)
nonisolated enum CompleteSignUpError: Error, Equatable, Sendable {
    case invalidEmail
    case invalidPassword           // length < 6
    case invalidDisplayName
    case userAlreadyExists
    case weakPassword
    case network
    case generic
}

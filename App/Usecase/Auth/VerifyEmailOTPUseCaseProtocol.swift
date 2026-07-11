protocol VerifyEmailOTPUseCaseProtocol: Sendable {
    /// Verifies the 6-digit signup OTP. On success a session exists and
    /// `.signedIn` has fired; when `displayName` is non-nil the
    /// `user_profiles` row is then created best-effort (a failure is
    /// non-fatal — email fallback + Settings rename cover it).
    /// `displayName` is nil on the deferred-verification path (user
    /// re-entered from the sign-in "email not confirmed" error).
    func verify(email: String, code: String, displayName: String?)
        async throws(VerifyEmailOTPError)
}

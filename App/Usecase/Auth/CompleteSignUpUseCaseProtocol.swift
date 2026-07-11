protocol CompleteSignUpUseCaseProtocol: Sendable {
    /// Registers via Supabase Auth and triggers the confirmation email
    /// (email confirmations are enabled, so no session is returned).
    /// The `user_profiles` row is created later by
    /// `VerifyEmailOTPUseCase`, once OTP verification yields a session.
    func completeSignUp(email: String, password: String, displayName: String)
        async throws(CompleteSignUpError)
}

/// Thin abstraction over Supabase Auth's session endpoints (sign-in,
/// signup-OTP verification, confirmation resend) so the Usecase layer
/// stays framework-free. The Infrastructure adapter
/// `SupabaseAuthSessionClient` maps Supabase's `AuthError` / `URLError`
/// into the typed enums below.
protocol AuthSessionClientProtocol: Sendable {
    func signIn(email: String, password: String) async throws(AuthSignInError)

    /// Exchanges the 6-digit signup OTP for a session. On success the
    /// SDK emits `.signedIn`, which RootView's auth observer picks up.
    func verifySignUpOTP(email: String, token: String) async throws(VerifyOTPClientError)

    func resendSignUpConfirmation(email: String) async throws(ResendConfirmationError)
}

nonisolated enum AuthSignInError: Error, Equatable, Sendable {
    /// GoTrue 400 with msg "Email not confirmed" — the account exists
    /// but the signup OTP was never verified. Detection is a string
    /// match (SDK 2.5.1 has no ErrorCode enum); pinned by CINT2.
    case emailNotConfirmed
    case invalidCredentials      // GoTrue 400 (other)
    case network                 // URLError
    case generic
}

nonisolated enum VerifyOTPClientError: Error, Equatable, Sendable {
    case invalidOrExpiredCode    // GoTrue 401 / 403
    case rateLimited             // GoTrue 429
    case network
    case generic
}

nonisolated enum ResendConfirmationError: Error, Equatable, Sendable {
    case rateLimited             // GoTrue 429 (max_frequency throttle)
    case network
    case generic
}

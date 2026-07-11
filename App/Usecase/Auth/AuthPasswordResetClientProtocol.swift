/// Thin abstraction over Supabase Auth's password-recovery endpoints
/// so the Usecase layer stays framework-free. The Infrastructure
/// adapter `SupabaseAuthPasswordResetClient` maps `AuthError` /
/// `URLError` into the typed enums below.
protocol AuthPasswordResetClientProtocol: Sendable {
    /// Sends the recovery email with the 6-digit OTP. GoTrue responds
    /// with success even for unknown emails (enumeration protection).
    /// "Resend" is this same call again — SDK 2.5.1's `resend` has no
    /// recovery type.
    func requestPasswordReset(email: String) async throws(PasswordResetRequestError)

    /// Exchanges the recovery OTP for a session. On success the SDK
    /// emits `.signedIn` (there is no dedicated recovery event in
    /// 2.5.1) — RootView flips to authenticated underneath the reset
    /// flow's cover.
    func verifyRecoveryOTP(email: String, token: String) async throws(VerifyOTPClientError)

    /// Sets a new password for the currently signed-in user (requires
    /// the session obtained from `verifyRecoveryOTP`).
    func updatePassword(_ newPassword: String) async throws(UpdatePasswordClientError)
}

nonisolated enum PasswordResetRequestError: Error, Equatable, Sendable {
    case rateLimited             // GoTrue 429 (max_frequency throttle)
    case network
    case generic
}

nonisolated enum UpdatePasswordClientError: Error, Equatable, Sendable {
    /// GoTrue 422 "New password should be different from the old
    /// password." — string match (SDK 2.5.1), pinned by DINT3.
    case samePassword
    case weakPassword            // apiError.weakPassword != nil
    case network
    case generic
}

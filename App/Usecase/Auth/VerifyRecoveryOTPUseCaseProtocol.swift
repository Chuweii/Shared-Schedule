protocol VerifyRecoveryOTPUseCaseProtocol: Sendable {
    /// Verifies the 6-digit recovery OTP. On success a session exists
    /// and `.signedIn` has fired — the reset flow then proceeds to the
    /// new-password step on top of the (now authenticated) root.
    func verify(email: String, code: String) async throws(VerifyRecoveryOTPError)
}

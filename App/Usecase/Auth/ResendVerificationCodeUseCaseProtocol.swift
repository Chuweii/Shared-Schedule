protocol ResendVerificationCodeUseCaseProtocol: Sendable {
    /// Resends the signup confirmation email (with the OTP) to `email`.
    func resend(email: String) async throws(ResendVerificationCodeError)
}

protocol UpdatePasswordUseCaseProtocol: Sendable {
    /// Sets a new password for the signed-in user (the recovery flow's
    /// final step — requires the session from `VerifyRecoveryOTPUseCase`).
    func update(newPassword: String) async throws(UpdatePasswordError)
}

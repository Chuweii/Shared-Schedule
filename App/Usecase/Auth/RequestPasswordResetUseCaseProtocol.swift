protocol RequestPasswordResetUseCaseProtocol: Sendable {
    /// Sends the recovery email. Succeeds regardless of whether the
    /// account exists (enumeration protection is server-side).
    func request(email: String) async throws(RequestPasswordResetError)
}

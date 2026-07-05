protocol DeleteAccountUseCaseProtocol: Sendable {
    /// Permanently delete the caller's account. The teardown that follows
    /// a success (sign-out / local session cleanup / routing back to
    /// login) is the Presentation layer's responsibility.
    func deleteAccount() async throws(DeleteAccountError)
}

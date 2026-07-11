protocol SignInUseCaseProtocol: Sendable {
    /// Signs in via Supabase Auth. On success the `.signedIn` auth
    /// state change flips RootView to the authenticated branch — the
    /// caller does not navigate manually.
    func signIn(email: String, password: String) async throws(SignInError)
}

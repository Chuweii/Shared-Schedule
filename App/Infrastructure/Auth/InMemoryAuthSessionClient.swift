/// Used by `AppDependencies.live` for SwiftUI previews. Production code
/// path (RootView) wires `SupabaseAuthSessionClient` directly. Always
/// succeeds — previews that exercise error paths should wire a fake
/// usecase at the ViewModel boundary instead.
nonisolated struct InMemoryAuthSessionClient: AuthSessionClientProtocol {
    func signIn(email: String, password: String) async throws(AuthSignInError) {
        // no-op
    }

    func verifySignUpOTP(email: String, token: String) async throws(VerifyOTPClientError) {
        // no-op
    }

    func resendSignUpConfirmation(email: String) async throws(ResendConfirmationError) {
        // no-op
    }
}

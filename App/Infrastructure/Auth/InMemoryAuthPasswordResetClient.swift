/// Used by `AppDependencies.live` for SwiftUI previews. Production code
/// path (RootView) wires `SupabaseAuthPasswordResetClient` directly.
/// Always succeeds — previews that exercise error paths should wire a
/// fake usecase at the ViewModel boundary instead.
nonisolated struct InMemoryAuthPasswordResetClient: AuthPasswordResetClientProtocol {
    func requestPasswordReset(email: String) async throws(PasswordResetRequestError) {
        // no-op
    }

    func verifyRecoveryOTP(email: String, token: String) async throws(VerifyOTPClientError) {
        // no-op
    }

    func updatePassword(_ newPassword: String) async throws(UpdatePasswordClientError) {
        // no-op
    }
}

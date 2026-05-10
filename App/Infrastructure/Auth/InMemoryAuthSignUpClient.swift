/// Used by `AppDependencies.live` for SwiftUI previews. Production code
/// path (RootView) wires `SupabaseAuthSignUpClient` directly. Always
/// succeeds — previews that exercise sign-up error paths should wire a
/// fake usecase at the ViewModel boundary instead.
nonisolated struct InMemoryAuthSignUpClient: AuthSignUpClientProtocol {
    func signUp(email: String, password: String) async throws(AuthSignUpError) {
        // no-op
    }
}

/// Thin abstraction over Supabase Auth's `signUp(email:password:)` so
/// the Usecase layer stays framework-free. The Infrastructure adapter
/// `SupabaseAuthSignUpClient` maps Supabase's `AuthError` / `URLError`
/// into the typed enum below.
protocol AuthSignUpClientProtocol: Sendable {
    func signUp(email: String, password: String) async throws(AuthSignUpError)
}

nonisolated enum AuthSignUpError: Error, Equatable, Sendable {
    case userAlreadyExists       // Supabase 422
    case weakPassword            // Supabase apiError.weakPassword != nil
    case network                 // URLError
    case generic
}

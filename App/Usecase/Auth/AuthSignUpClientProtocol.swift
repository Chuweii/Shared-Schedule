/// Thin abstraction over Supabase Auth's `signUp` so the Usecase layer
/// stays framework-free. The Infrastructure adapter
/// `SupabaseAuthSignUpClient` maps Supabase's `AuthError` / `URLError`
/// into the typed enum below.
protocol AuthSignUpClientProtocol: Sendable {
    /// `displayName` travels as signUp metadata
    /// (`auth.users.raw_user_meta_data.display_name`) — a server-side
    /// record only. The `user_profiles` row is created after OTP
    /// verification (`VerifyEmailOTPUseCase`), because with email
    /// confirmations enabled signUp returns no session.
    func signUp(email: String, password: String, displayName: String)
        async throws(AuthSignUpError)
}

nonisolated enum AuthSignUpError: Error, Equatable, Sendable {
    case userAlreadyExists       // Supabase 422
    case weakPassword            // Supabase apiError.weakPassword != nil
    case network                 // URLError
    case generic
}

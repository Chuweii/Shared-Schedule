import Auth
import Foundation
// AnyJSON's members live in the SDK's internal `_Helpers` target in
// supabase-swift 2.5.1; MemberImportVisibility requires importing it to
// build the signUp metadata payload. Revisit on SDK upgrade.
import _Helpers

/// Infrastructure adapter that maps Supabase's `AuthError` / `URLError`
/// into our framework-free `AuthSignUpError`. Wired into
/// `AppDependencies.live` so the Usecase layer never imports `Auth`.
final class SupabaseAuthSignUpClient: AuthSignUpClientProtocol, @unchecked Sendable {
    private let authClient: AuthClient

    init(authClient: AuthClient = SupabaseClientProvider.auth) {
        self.authClient = authClient
    }

    func signUp(email: String, password: String, displayName: String)
        async throws(AuthSignUpError)
    {
        do {
            try await authClient.signUp(
                email: email,
                password: password,
                data: ["display_name": .string(displayName)]
            )
        } catch let urlError as URLError {
            _ = urlError
            throw .network
        } catch let authError as AuthError {
            if case let AuthError.api(apiError) = authError {
                if apiError.weakPassword != nil { throw .weakPassword }
                if apiError.code == 422 { throw .userAlreadyExists }
            }
            throw .generic
        } catch {
            throw .generic
        }
    }
}

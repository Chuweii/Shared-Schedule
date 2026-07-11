import Auth
import Foundation

/// Infrastructure adapter that maps Supabase's `AuthError` / `URLError`
/// into the framework-free `AuthSessionClientProtocol` enums. SDK 2.5.1
/// has no ErrorCode enum, so "email not confirmed" detection is a
/// case-insensitive string match on `APIError.msg` — pinned by the
/// CINT2 integration test so an SDK bump surfaces any drift.
final class SupabaseAuthSessionClient: AuthSessionClientProtocol, @unchecked Sendable {
    private let authClient: AuthClient

    init(authClient: AuthClient = SupabaseClientProvider.auth) {
        self.authClient = authClient
    }

    func signIn(email: String, password: String) async throws(AuthSignInError) {
        do {
            try await authClient.signIn(email: email, password: password)
        } catch {
            throw Self.mapSignInError(error)
        }
    }

    func verifySignUpOTP(email: String, token: String) async throws(VerifyOTPClientError) {
        do {
            try await authClient.verifyOTP(email: email, token: token, type: .signup)
        } catch {
            throw Self.mapVerifyError(error)
        }
    }

    func resendSignUpConfirmation(email: String) async throws(ResendConfirmationError) {
        do {
            try await authClient.resend(email: email, type: .signup)
        } catch {
            throw Self.mapResendError(error)
        }
    }

    // MARK: - Error mapping (static for unit-testability without network)

    static func mapSignInError(_ error: Error) -> AuthSignInError {
        if error is URLError { return .network }
        if case let AuthError.api(apiError) = error, apiError.code == 400 {
            if apiError.msg?.lowercased().contains("email not confirmed") == true {
                return .emailNotConfirmed
            }
            return .invalidCredentials
        }
        return .generic
    }

    static func mapVerifyError(_ error: Error) -> VerifyOTPClientError {
        if error is URLError { return .network }
        if case let AuthError.api(apiError) = error {
            switch apiError.code {
            case 401, 403: return .invalidOrExpiredCode
            case 429: return .rateLimited
            default: break
            }
        }
        return .generic
    }

    static func mapResendError(_ error: Error) -> ResendConfirmationError {
        if error is URLError { return .network }
        if case let AuthError.api(apiError) = error, apiError.code == 429 {
            return .rateLimited
        }
        return .generic
    }
}

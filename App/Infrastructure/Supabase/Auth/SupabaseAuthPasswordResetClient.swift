import Auth
import Foundation

/// Infrastructure adapter for the password-recovery endpoints. Error
/// detection is status-code + string matching (SDK 2.5.1 has no
/// ErrorCode enum) — pinned by the DINT2/DINT3 integration tests.
final class SupabaseAuthPasswordResetClient: AuthPasswordResetClientProtocol, @unchecked Sendable {
    private let authClient: AuthClient

    init(authClient: AuthClient = SupabaseClientProvider.auth) {
        self.authClient = authClient
    }

    func requestPasswordReset(email: String) async throws(PasswordResetRequestError) {
        do {
            try await authClient.resetPasswordForEmail(email)
        } catch {
            throw Self.mapRequestError(error)
        }
    }

    func verifyRecoveryOTP(email: String, token: String) async throws(VerifyOTPClientError) {
        do {
            try await authClient.verifyOTP(email: email, token: token, type: .recovery)
        } catch {
            // Same GoTrue /verify endpoint as the signup flow — reuse
            // the session client's mapper instead of duplicating it.
            throw SupabaseAuthSessionClient.mapVerifyError(error)
        }
    }

    func updatePassword(_ newPassword: String) async throws(UpdatePasswordClientError) {
        do {
            _ = try await authClient.update(user: UserAttributes(password: newPassword))
        } catch {
            throw Self.mapUpdateError(error)
        }
    }

    // MARK: - Error mapping (static for unit-testability without network)

    static func mapRequestError(_ error: Error) -> PasswordResetRequestError {
        if error is URLError { return .network }
        if case let AuthError.api(apiError) = error, apiError.code == 429 {
            return .rateLimited
        }
        return .generic
    }

    static func mapUpdateError(_ error: Error) -> UpdatePasswordClientError {
        if error is URLError { return .network }
        if case let AuthError.api(apiError) = error {
            if apiError.weakPassword != nil { return .weakPassword }
            if apiError.code == 422,
               apiError.msg?.lowercased().contains("different from the old password") == true {
                return .samePassword
            }
        }
        return .generic
    }
}

import Testing
import Foundation
import Auth
@testable import Shared_Schedule

/// Pure unit tests (no network, no `.integration` tag): decode
/// `AuthError.APIError` JSON fixtures and assert the static mapping.
/// The live GoTrue payloads themselves are pinned by CINT2/CINT3.
/// (Migrated from the Slice A `LoginViewModelTests.describe_*` tests —
/// `LoginViewModel` no longer maps raw auth errors.)
struct SupabaseAuthSessionClientErrorMappingTests {

    // MARK: - mapSignInError

    @Test("SM1. 400 'Invalid login credentials' → .invalidCredentials")
    func mapSignInError_400InvalidCredentials_returnsInvalidCredentials() throws {
        // Given
        let error = try authAPIError(code: 400, msg: "Invalid login credentials")

        // When
        let mapped = SupabaseAuthSessionClient.mapSignInError(error)

        // Then
        #expect(mapped == .invalidCredentials)
    }

    @Test("SM2. 400 'Email not confirmed'（大小寫不敏感）→ .emailNotConfirmed")
    func mapSignInError_400EmailNotConfirmed_returnsEmailNotConfirmed() throws {
        // Given
        let error = try authAPIError(code: 400, msg: "Email not confirmed")

        // When
        let mapped = SupabaseAuthSessionClient.mapSignInError(error)

        // Then
        #expect(mapped == .emailNotConfirmed)
    }

    @Test("SM3. URLError → .network")
    func mapSignInError_urlError_returnsNetwork() {
        // Given
        let error = URLError(.notConnectedToInternet)

        // When
        let mapped = SupabaseAuthSessionClient.mapSignInError(error)

        // Then
        #expect(mapped == .network)
    }

    @Test("SM4. 非 AuthError、非 URLError → .generic")
    func mapSignInError_unknownError_returnsGeneric() {
        // Given
        struct OtherError: Error {}

        // When
        let mapped = SupabaseAuthSessionClient.mapSignInError(OtherError())

        // Then
        #expect(mapped == .generic)
    }

    // MARK: - mapVerifyError

    @Test("SM5. 401/403 'Token has expired or is invalid' → .invalidOrExpiredCode", arguments: [401, 403])
    func mapVerifyError_expiredToken_returnsInvalidOrExpiredCode(code: Int) throws {
        // Given
        let error = try authAPIError(code: code, msg: "Token has expired or is invalid")

        // When
        let mapped = SupabaseAuthSessionClient.mapVerifyError(error)

        // Then
        #expect(mapped == .invalidOrExpiredCode)
    }

    @Test("SM6. 429 → .rateLimited")
    func mapVerifyError_429_returnsRateLimited() throws {
        // Given
        let error = try authAPIError(code: 429, msg: "For security purposes, you can only request this after 1 seconds.")

        // When
        let mapped = SupabaseAuthSessionClient.mapVerifyError(error)

        // Then
        #expect(mapped == .rateLimited)
    }

    // MARK: - mapResendError

    @Test("SM7. 429 → .rateLimited")
    func mapResendError_429_returnsRateLimited() throws {
        // Given
        let error = try authAPIError(code: 429, msg: "For security purposes, you can only request this after 1 seconds.")

        // When
        let mapped = SupabaseAuthSessionClient.mapResendError(error)

        // Then
        #expect(mapped == .rateLimited)
    }

    // MARK: - Helpers

    private func authAPIError(code: Int, msg: String) throws -> AuthError {
        let json = """
        {"code": \(code), "msg": "\(msg)"}
        """.data(using: .utf8)!
        let apiError = try AuthClient.Configuration.jsonDecoder.decode(AuthError.APIError.self, from: json)
        return AuthError.api(apiError)
    }
}

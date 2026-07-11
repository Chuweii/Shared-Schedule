import Testing
import Foundation
import Auth
@testable import Shared_Schedule

/// Pure unit tests (no network, no `.integration` tag): decode
/// `AuthError.APIError` JSON fixtures and assert the static mapping.
/// Live GoTrue payloads are pinned by DINT2/DINT3.
struct SupabaseAuthPasswordResetClientErrorMappingTests {

    @Test("PM1. 429 → .rateLimited")
    func mapRequestError_429_returnsRateLimited() throws {
        // Given
        let error = try authAPIError(code: 429, msg: "For security purposes, you can only request this after 1 seconds.")

        // When
        let mapped = SupabaseAuthPasswordResetClient.mapRequestError(error)

        // Then
        #expect(mapped == .rateLimited)
    }

    @Test("PM2. 401/403 'Token has expired or is invalid' → .invalidOrExpiredCode（重用 session client mapper）", arguments: [401, 403])
    func mapVerifyError_expiredToken_returnsInvalidOrExpiredCode(code: Int) throws {
        // Given
        let error = try authAPIError(code: code, msg: "Token has expired or is invalid")

        // When — the reset client delegates /verify mapping to the
        // session client's mapper
        let mapped = SupabaseAuthSessionClient.mapVerifyError(error)

        // Then
        #expect(mapped == .invalidOrExpiredCode)
    }

    @Test("PM3. 422 'New password should be different...' → .samePassword")
    func mapUpdateError_422SamePassword_returnsSamePassword() throws {
        // Given
        let error = try authAPIError(
            code: 422,
            msg: "New password should be different from the old password."
        )

        // When
        let mapped = SupabaseAuthPasswordResetClient.mapUpdateError(error)

        // Then
        #expect(mapped == .samePassword)
    }

    @Test("PM4. 422 + weak_password → .weakPassword")
    func mapUpdateError_weakPassword_returnsWeakPassword() throws {
        // Given
        let json = #"""
        {"code": 422, "msg": "Password should be at least 6 characters.", "weak_password": {"reasons": ["length"]}}
        """#.data(using: .utf8)!
        let apiError = try AuthClient.Configuration.jsonDecoder.decode(AuthError.APIError.self, from: json)
        let error = AuthError.api(apiError)

        // When
        let mapped = SupabaseAuthPasswordResetClient.mapUpdateError(error)

        // Then
        #expect(mapped == .weakPassword)
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

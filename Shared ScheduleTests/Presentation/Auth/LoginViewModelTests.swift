import Testing
import Foundation
import Auth
@testable import Shared_Schedule

struct LoginViewModelTests {

    // MARK: - describe

    @Test("URLError → 網路錯誤訊息")
    func describe_URLError_returnsNetworkMessage() {
        // Given
        let error = URLError(.notConnectedToInternet)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == String(localized: "loginErrorNetwork"))
    }

    @Test("AuthError 含 weakPassword — 密碼強度錯誤訊息")
    func describe_authErrorWithWeakPassword_returnsWeakPasswordMessage() throws {
        // Given — 422 + weak_password JSON
        let json = #"""
        {"code": 422, "weak_password": {"reasons": ["length"]}}
        """#.data(using: .utf8)!
        let apiError = try AuthClient.Configuration.jsonDecoder.decode(AuthError.APIError.self, from: json)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == String(localized: "loginErrorWeakPassword"))
    }

    @Test("AuthError 400 — 帳密錯誤訊息")
    func describe_authError400_returnsInvalidCredentialsMessage() throws {
        // Given
        let apiError = try decodeAPIError(code: 400)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == String(localized: "loginErrorInvalidCredentials"))
    }

    @Test("AuthError 422 不含 weakPassword — 帳號已存在訊息")
    func describe_authError422WithoutWeakPassword_returnsUserExistsMessage() throws {
        // Given
        let apiError = try decodeAPIError(code: 422)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == String(localized: "loginErrorUserExists"))
    }

    @Test("AuthError 其他 status — 通用錯誤訊息")
    func describe_authErrorOtherCode_returnsGenericMessage() throws {
        // Given
        let apiError = try decodeAPIError(code: 500)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == String(localized: "loginErrorGeneric"))
    }

    @Test("非 AuthError、非 URLError — 通用錯誤訊息")
    func describe_unknownError_returnsGenericMessage() {
        // Given
        struct OtherError: Error {}
        let error = OtherError()

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == String(localized: "loginErrorGeneric"))
    }

    // MARK: - Helpers

    private func decodeAPIError(code: Int) throws -> AuthError.APIError {
        let json = "{\"code\": \(code)}".data(using: .utf8)!
        return try AuthClient.Configuration.jsonDecoder.decode(AuthError.APIError.self, from: json)
    }
}

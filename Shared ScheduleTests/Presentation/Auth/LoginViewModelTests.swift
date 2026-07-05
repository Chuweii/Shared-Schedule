import Testing
import Foundation
import Auth
@testable import Shared_Schedule

struct LoginViewModelTests {

    // MARK: - describe

    @Test("URLError → .network")
    func describe_URLError_returnsNetworkMessage() {
        // Given
        let error = URLError(.notConnectedToInternet)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == .network)
    }

    @Test("AuthError 含 weakPassword → .weakPassword")
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
        #expect(message == .weakPassword)
    }

    @Test("AuthError 400 → .invalidCredentials")
    func describe_authError400_returnsInvalidCredentialsMessage() throws {
        // Given
        let apiError = try decodeAPIError(code: 400)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == .invalidCredentials)
    }

    @Test("AuthError 422 不含 weakPassword → .userExists")
    func describe_authError422WithoutWeakPassword_returnsUserExistsMessage() throws {
        // Given
        let apiError = try decodeAPIError(code: 422)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == .userExists)
    }

    @Test("AuthError 其他 status → .generic")
    func describe_authErrorOtherCode_returnsGenericMessage() throws {
        // Given
        let apiError = try decodeAPIError(code: 500)
        let error = AuthError.api(apiError)

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == .generic)
    }

    @Test("非 AuthError、非 URLError → .generic")
    func describe_unknownError_returnsGenericMessage() {
        // Given
        struct OtherError: Error {}
        let error = OtherError()

        // When
        let message = LoginViewModel.describe(error)

        // Then
        #expect(message == .generic)
    }

    // MARK: - Helpers

    private func decodeAPIError(code: Int) throws -> AuthError.APIError {
        let json = "{\"code\": \(code)}".data(using: .utf8)!
        return try AuthClient.Configuration.jsonDecoder.decode(AuthError.APIError.self, from: json)
    }

    // MARK: - signUp() — Slice A (LVM1-LVM4)

    @MainActor
    private func makeSignUpSUT() -> (vm: LoginViewModel, fakeUseCase: FakeCompleteSignUpUseCase) {
        let fake = FakeCompleteSignUpUseCase()
        let vm = LoginViewModel(completeSignUpUseCase: fake)
        return (vm, fake)
    }

    @MainActor
    @Test("LVM1. signUp 三欄全有效 + fakeUseCase 設成功 → error nil、isLoading 結束為 false、useCase called 1 次帶正確 args")
    func signUp_validInputs_succeedsAndCallsUseCase() async {
        // Given
        let (vm, fakeUseCase) = makeSignUpSUT()
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = "小明"

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
        #expect(fakeUseCase.callCount == 1)
        #expect(fakeUseCase.lastEmail == "x@y.com")
        #expect(fakeUseCase.lastPassword == "password123")
        #expect(fakeUseCase.lastDisplayName == "小明")
    }

    @MainActor
    @Test("LVM2. signUp displayName 留空 → error == .emptyDisplayName、useCase 未呼叫")
    func signUp_emptyDisplayName_failsPreflight() async {
        // Given
        let (vm, fakeUseCase) = makeSignUpSUT()
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = ""

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == .emptyDisplayName)
        #expect(fakeUseCase.callCount == 0)
    }

    @MainActor
    @Test("LVM3. signUp fakeUseCase 拋 .userAlreadyExists → error == .userExists")
    func signUp_useCaseUserAlreadyExists_setsErrorMessage() async {
        // Given
        let (vm, fakeUseCase) = makeSignUpSUT()
        fakeUseCase.errorToThrow = .userAlreadyExists
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = "小明"

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == .userExists)
    }

    @MainActor
    @Test("LVM4. signUp fakeUseCase 拋 .partialFailure → error == .partialFailure")
    func signUp_useCasePartialFailure_setsRestartMessage() async {
        // Given
        let (vm, fakeUseCase) = makeSignUpSUT()
        fakeUseCase.errorToThrow = .partialFailure
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = "小明"

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == .partialFailure)
    }
}

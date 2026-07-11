import Testing
import Foundation
@testable import Shared_Schedule

struct CompleteSignUpUseCaseTests {

    private func makeSUT() -> (useCase: CompleteSignUpUseCase, authFake: FakeAuthClient) {
        let authFake = FakeAuthClient()
        let useCase = CompleteSignUpUseCase(authSignUpClient: authFake)
        return (useCase, authFake)
    }

    @Test("UC1'. 三欄全有效 → usecase 成功；client called 1 次帶 trim 後 displayName（進 metadata）")
    func completeSignUp_validInputs_callsClientWithDisplayName() async throws {
        // Given
        let (useCase, authFake) = makeSUT()

        // When
        try await useCase.completeSignUp(
            email: "x@y.com",
            password: "password123",
            displayName: "  小明  "
        )

        // Then
        #expect(authFake.signUpCount == 1)
        #expect(authFake.lastEmail == "x@y.com")
        #expect(authFake.lastPassword == "password123")
        #expect(authFake.lastDisplayName == "小明")
    }

    @Test("UC2. displayName 全 whitespace（pre-flight）→ throws .invalidDisplayName；client 未呼叫")
    func completeSignUp_whitespaceDisplayName_failsPreflight() async {
        // Given
        let (useCase, authFake) = makeSUT()

        // When / Then
        await #expect(throws: CompleteSignUpError.invalidDisplayName) {
            try await useCase.completeSignUp(
                email: "x@y.com",
                password: "password123",
                displayName: "   "
            )
        }
        #expect(authFake.signUpCount == 0)
    }

    @Test("UC3. password < 6 chars（pre-flight）→ throws .invalidPassword；client 未呼叫")
    func completeSignUp_shortPassword_failsPreflight() async {
        // Given
        let (useCase, authFake) = makeSUT()

        // When / Then
        await #expect(throws: CompleteSignUpError.invalidPassword) {
            try await useCase.completeSignUp(
                email: "x@y.com",
                password: "12345",
                displayName: "小明"
            )
        }
        #expect(authFake.signUpCount == 0)
    }

    @Test("UC4. email empty（pre-flight）→ throws .invalidEmail；client 未呼叫")
    func completeSignUp_emptyEmail_failsPreflight() async {
        // Given
        let (useCase, authFake) = makeSUT()

        // When / Then
        await #expect(throws: CompleteSignUpError.invalidEmail) {
            try await useCase.completeSignUp(
                email: "   ",
                password: "password123",
                displayName: "小明"
            )
        }
        #expect(authFake.signUpCount == 0)
    }

    @Test("UC5. client 拋 .userAlreadyExists → throws .userAlreadyExists")
    func completeSignUp_authThrowsUserExists_passthrough() async {
        // Given
        let (useCase, authFake) = makeSUT()
        authFake.signUpError = .userAlreadyExists

        // When / Then
        await #expect(throws: CompleteSignUpError.userAlreadyExists) {
            try await useCase.completeSignUp(
                email: "x@y.com",
                password: "password123",
                displayName: "小明"
            )
        }
    }
}

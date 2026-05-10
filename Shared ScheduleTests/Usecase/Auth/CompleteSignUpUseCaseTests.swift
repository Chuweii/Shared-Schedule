import Testing
import Foundation
@testable import Shared_Schedule

struct CompleteSignUpUseCaseTests {

    private static let userID = UserID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

    private func makeSUT() -> (
        useCase: CompleteSignUpUseCase,
        authFake: FakeAuthClient,
        profileFake: FakeUserProfileRepository
    ) {
        let authFake = FakeAuthClient()
        let profileFake = FakeUserProfileRepository()
        let useCase = CompleteSignUpUseCase(
            authSignUpClient: authFake,
            userProfileRepository: profileFake
        )
        return (useCase, authFake, profileFake)
    }

    @Test("UC1. 三欄全有效，auth 成功 + profile 成功 → usecase 成功；兩個 fake 各 called 1 次帶正確 args")
    func completeSignUp_validInputs_callsBothAndReturns() async throws {
        // Given
        let (useCase, authFake, profileFake) = makeSUT()
        profileFake.createResult = try UserProfile(userID: Self.userID, displayName: "小明")

        // When
        try await useCase.completeSignUp(
            email: "x@y.com",
            password: "password123",
            displayName: "小明"
        )

        // Then
        #expect(authFake.signUpCount == 1)
        #expect(authFake.lastEmail == "x@y.com")
        #expect(authFake.lastPassword == "password123")
        #expect(profileFake.createCount == 1)
        #expect(profileFake.lastCreateDisplayName == "小明")
    }

    @Test("UC2. displayName 全 whitespace（pre-flight）→ throws .invalidDisplayName；auth/profile 都未呼叫")
    func completeSignUp_whitespaceDisplayName_failsPreflight() async {
        // Given
        let (useCase, authFake, profileFake) = makeSUT()

        // When / Then
        await #expect(throws: CompleteSignUpError.invalidDisplayName) {
            try await useCase.completeSignUp(
                email: "x@y.com",
                password: "password123",
                displayName: "   "
            )
        }
        #expect(authFake.signUpCount == 0)
        #expect(profileFake.createCount == 0)
    }

    @Test("UC3. password < 6 chars（pre-flight）→ throws .invalidPassword；auth 未呼叫")
    func completeSignUp_shortPassword_failsPreflight() async {
        // Given
        let (useCase, authFake, _) = makeSUT()

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

    @Test("UC4. email empty（pre-flight）→ throws .invalidEmail；auth 未呼叫")
    func completeSignUp_emptyEmail_failsPreflight() async {
        // Given
        let (useCase, authFake, _) = makeSUT()

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

    @Test("UC5. auth.signUp 拋 .userAlreadyExists → throws .userAlreadyExists；profile.create 未呼叫")
    func completeSignUp_authThrowsUserExists_passthroughAndSkipsProfile() async {
        // Given
        let (useCase, _, profileFake) = makeSUT()
        let authFake = FakeAuthClient()
        authFake.signUpError = .userAlreadyExists
        let useCase2 = CompleteSignUpUseCase(
            authSignUpClient: authFake,
            userProfileRepository: profileFake
        )

        // When / Then
        await #expect(throws: CompleteSignUpError.userAlreadyExists) {
            try await useCase2.completeSignUp(
                email: "x@y.com",
                password: "password123",
                displayName: "小明"
            )
        }
        #expect(profileFake.createCount == 0)
        _ = useCase  // silence unused
    }

    @Test("UC6. auth 成功；profile.create 拋 .persistenceFailure → throws .partialFailure")
    func completeSignUp_profileFailsAfterAuth_throwsPartialFailure() async {
        // Given
        let (useCase, _, profileFake) = makeSUT()
        profileFake.createError = .persistenceFailure

        // When / Then
        await #expect(throws: CompleteSignUpError.partialFailure) {
            try await useCase.completeSignUp(
                email: "x@y.com",
                password: "password123",
                displayName: "小明"
            )
        }
    }

    @Test("UC7. auth 成功；profile.create 拋 .alreadyExists（重試 race）→ usecase 視為成功，不 throw")
    func completeSignUp_profileAlreadyExists_treatedAsSuccess() async throws {
        // Given
        let (useCase, _, profileFake) = makeSUT()
        profileFake.createError = .alreadyExists

        // When / Then — should not throw
        try await useCase.completeSignUp(
            email: "x@y.com",
            password: "password123",
            displayName: "小明"
        )
    }
}

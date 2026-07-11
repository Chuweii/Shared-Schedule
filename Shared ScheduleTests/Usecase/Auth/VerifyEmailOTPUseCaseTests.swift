import Testing
import Foundation
@testable import Shared_Schedule

struct VerifyEmailOTPUseCaseTests {

    private static let userID = UserID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

    private func makeSUT() -> (
        useCase: VerifyEmailOTPUseCase,
        clientFake: FakeAuthSessionClient,
        profileFake: FakeUserProfileRepository
    ) {
        let clientFake = FakeAuthSessionClient()
        let profileFake = FakeUserProfileRepository()
        let useCase = VerifyEmailOTPUseCase(
            authSessionClient: clientFake,
            userProfileRepository: profileFake
        )
        return (useCase, clientFake, profileFake)
    }

    @Test("VE1. 正確 6 碼 + displayName → 驗證後建檔，displayName 已 trim")
    func verify_validCodeWithDisplayName_verifiesThenCreatesProfile() async throws {
        // Given
        let (useCase, clientFake, profileFake) = makeSUT()
        profileFake.createResult = try UserProfile(userID: Self.userID, displayName: "小明")

        // When
        try await useCase.verify(email: "x@y.com", code: "123456", displayName: "  小明  ")

        // Then
        #expect(clientFake.verifyCount == 1)
        #expect(clientFake.lastVerifyEmail == "x@y.com")
        #expect(clientFake.lastVerifyToken == "123456")
        #expect(profileFake.createCount == 1)
        #expect(profileFake.lastCreateDisplayName == "小明")
    }

    @Test("VE2. displayName = nil（延後驗證路徑）→ 驗證成功、不建檔")
    func verify_nilDisplayName_skipsProfileCreation() async throws {
        // Given
        let (useCase, clientFake, profileFake) = makeSUT()

        // When
        try await useCase.verify(email: "x@y.com", code: "123456", displayName: nil)

        // Then
        #expect(clientFake.verifyCount == 1)
        #expect(profileFake.createCount == 0)
    }

    @Test("VE3. 僅 5 碼 → throws .invalidCodeFormat；client 未呼叫")
    func verify_fiveDigitCode_failsFormatPreflight() async {
        // Given
        let (useCase, clientFake, _) = makeSUT()

        // When / Then
        await #expect(throws: VerifyEmailOTPError.invalidCodeFormat) {
            try await useCase.verify(email: "x@y.com", code: "12345", displayName: "小明")
        }
        #expect(clientFake.verifyCount == 0)
    }

    @Test("VE4. 含非數字 → throws .invalidCodeFormat；client 未呼叫")
    func verify_nonDigitCode_failsFormatPreflight() async {
        // Given
        let (useCase, clientFake, _) = makeSUT()

        // When / Then
        await #expect(throws: VerifyEmailOTPError.invalidCodeFormat) {
            try await useCase.verify(email: "x@y.com", code: "12345a", displayName: "小明")
        }
        #expect(clientFake.verifyCount == 0)
    }

    @Test("VE5. client 拋 .invalidOrExpiredCode → throws .invalidOrExpiredCode；不建檔")
    func verify_clientInvalidOrExpiredCode_mapsAndSkipsProfile() async {
        // Given
        let (useCase, clientFake, profileFake) = makeSUT()
        clientFake.verifyError = .invalidOrExpiredCode

        // When / Then
        await #expect(throws: VerifyEmailOTPError.invalidOrExpiredCode) {
            try await useCase.verify(email: "x@y.com", code: "123456", displayName: "小明")
        }
        #expect(profileFake.createCount == 0)
    }

    @Test("VE6. client 拋 .rateLimited → throws .rateLimited")
    func verify_clientRateLimited_mapsToRateLimited() async {
        // Given
        let (useCase, clientFake, _) = makeSUT()
        clientFake.verifyError = .rateLimited

        // When / Then
        await #expect(throws: VerifyEmailOTPError.rateLimited) {
            try await useCase.verify(email: "x@y.com", code: "123456", displayName: "小明")
        }
    }

    @Test(
        "VE7. 驗證成功、建檔失敗（best-effort、非致命）→ 不 throw",
        arguments: [UserProfileError.persistenceFailure, UserProfileError.alreadyExists]
    )
    func verify_profileCreationFails_stillSucceeds(profileError: UserProfileError) async throws {
        // Given
        let (useCase, clientFake, profileFake) = makeSUT()
        profileFake.createError = profileError

        // When / Then — should not throw
        try await useCase.verify(email: "x@y.com", code: "123456", displayName: "小明")
        #expect(clientFake.verifyCount == 1)
        #expect(profileFake.createCount == 1)
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

struct VerifyRecoveryOTPUseCaseTests {

    private func makeSUT() -> (
        useCase: VerifyRecoveryOTPUseCase,
        clientFake: FakeAuthPasswordResetClient
    ) {
        let clientFake = FakeAuthPasswordResetClient()
        let useCase = VerifyRecoveryOTPUseCase(authPasswordResetClient: clientFake)
        return (useCase, clientFake)
    }

    @Test("VR1. 正確 6 碼 → 不 throw；client called 1 次、email 已 trim")
    func verify_validCode_callsClient() async throws {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When
        try await useCase.verify(email: "  x@y.com  ", code: "123456")

        // Then
        #expect(clientFake.verifyCount == 1)
        #expect(clientFake.lastVerifyEmail == "x@y.com")
        #expect(clientFake.lastVerifyToken == "123456")
    }

    @Test("VR2. 僅 5 碼 → throws .invalidCodeFormat；client 未呼叫")
    func verify_fiveDigitCode_failsFormatPreflight() async {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When / Then
        await #expect(throws: VerifyRecoveryOTPError.invalidCodeFormat) {
            try await useCase.verify(email: "x@y.com", code: "12345")
        }
        #expect(clientFake.verifyCount == 0)
    }

    @Test("VR3. 含非數字 → throws .invalidCodeFormat；client 未呼叫")
    func verify_nonDigitCode_failsFormatPreflight() async {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When / Then
        await #expect(throws: VerifyRecoveryOTPError.invalidCodeFormat) {
            try await useCase.verify(email: "x@y.com", code: "12345a")
        }
        #expect(clientFake.verifyCount == 0)
    }

    @Test(
        "VR4. client 拋 .invalidOrExpiredCode / .rateLimited / .network → 對應映射",
        arguments: [
            (VerifyOTPClientError.invalidOrExpiredCode, VerifyRecoveryOTPError.invalidOrExpiredCode),
            (VerifyOTPClientError.rateLimited, VerifyRecoveryOTPError.rateLimited),
            (VerifyOTPClientError.network, VerifyRecoveryOTPError.network),
        ]
    )
    func verify_clientError_mapsThrough(
        clientError: VerifyOTPClientError,
        expected: VerifyRecoveryOTPError
    ) async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.verifyError = clientError

        // When / Then
        await #expect(throws: expected) {
            try await useCase.verify(email: "x@y.com", code: "123456")
        }
    }
}

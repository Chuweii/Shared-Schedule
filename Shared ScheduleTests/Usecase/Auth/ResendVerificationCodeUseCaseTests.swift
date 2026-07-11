import Testing
import Foundation
@testable import Shared_Schedule

struct ResendVerificationCodeUseCaseTests {

    private func makeSUT() -> (
        useCase: ResendVerificationCodeUseCase,
        clientFake: FakeAuthSessionClient
    ) {
        let clientFake = FakeAuthSessionClient()
        let useCase = ResendVerificationCodeUseCase(authSessionClient: clientFake)
        return (useCase, clientFake)
    }

    @Test("RV1. email 前後空白 + client 成功 → 不 throw；client called 1 次、email 已 trim")
    func resend_validEmail_callsClientWithTrimmedEmail() async throws {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When
        try await useCase.resend(email: "  x@y.com  ")

        // Then
        #expect(clientFake.resendCount == 1)
        #expect(clientFake.lastResendEmail == "x@y.com")
    }

    @Test("RV2. client 拋 .rateLimited → throws .rateLimited")
    func resend_clientRateLimited_mapsToRateLimited() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.resendError = .rateLimited

        // When / Then
        await #expect(throws: ResendVerificationCodeError.rateLimited) {
            try await useCase.resend(email: "x@y.com")
        }
    }

    @Test("RV3. client 拋 .network → throws .network")
    func resend_clientNetworkError_mapsToNetwork() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.resendError = .network

        // When / Then
        await #expect(throws: ResendVerificationCodeError.network) {
            try await useCase.resend(email: "x@y.com")
        }
    }
}

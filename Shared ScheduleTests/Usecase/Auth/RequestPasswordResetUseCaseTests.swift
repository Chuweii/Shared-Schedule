import Testing
import Foundation
@testable import Shared_Schedule

struct RequestPasswordResetUseCaseTests {

    private func makeSUT() -> (
        useCase: RequestPasswordResetUseCase,
        clientFake: FakeAuthPasswordResetClient
    ) {
        let clientFake = FakeAuthPasswordResetClient()
        let useCase = RequestPasswordResetUseCase(authPasswordResetClient: clientFake)
        return (useCase, clientFake)
    }

    @Test("RP1. email 前後空白 + client 成功 → 不 throw；client called 1 次、email 已 trim")
    func request_validEmail_callsClientWithTrimmedEmail() async throws {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When
        try await useCase.request(email: "  x@y.com  ")

        // Then
        #expect(clientFake.requestCount == 1)
        #expect(clientFake.lastRequestEmail == "x@y.com")
    }

    @Test("RP2. email 全 whitespace（pre-flight）→ throws .emptyEmail；client 未呼叫")
    func request_blankEmail_failsPreflight() async {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When / Then
        await #expect(throws: RequestPasswordResetError.emptyEmail) {
            try await useCase.request(email: "   ")
        }
        #expect(clientFake.requestCount == 0)
    }

    @Test(
        "RP3. client 拋 .rateLimited / .network → 對應映射",
        arguments: [
            (PasswordResetRequestError.rateLimited, RequestPasswordResetError.rateLimited),
            (PasswordResetRequestError.network, RequestPasswordResetError.network),
        ]
    )
    func request_clientError_mapsThrough(
        clientError: PasswordResetRequestError,
        expected: RequestPasswordResetError
    ) async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.requestError = clientError

        // When / Then
        await #expect(throws: expected) {
            try await useCase.request(email: "x@y.com")
        }
    }
}

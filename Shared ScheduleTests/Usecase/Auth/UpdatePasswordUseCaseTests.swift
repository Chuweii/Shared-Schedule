import Testing
import Foundation
@testable import Shared_Schedule

struct UpdatePasswordUseCaseTests {

    private func makeSUT() -> (
        useCase: UpdatePasswordUseCase,
        clientFake: FakeAuthPasswordResetClient
    ) {
        let clientFake = FakeAuthPasswordResetClient()
        let useCase = UpdatePasswordUseCase(authPasswordResetClient: clientFake)
        return (useCase, clientFake)
    }

    @Test("UP1. 有效新密碼 → 不 throw；client called 1 次")
    func update_validPassword_callsClient() async throws {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When
        try await useCase.update(newPassword: "newpassword456")

        // Then
        #expect(clientFake.updateCount == 1)
        #expect(clientFake.lastNewPassword == "newpassword456")
    }

    @Test("UP2. 新密碼 < 6 chars（pre-flight）→ throws .shortPassword；client 未呼叫")
    func update_shortPassword_failsPreflight() async {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When / Then
        await #expect(throws: UpdatePasswordError.shortPassword) {
            try await useCase.update(newPassword: "12345")
        }
        #expect(clientFake.updateCount == 0)
    }

    @Test("UP3. client 拋 .samePassword → throws .samePassword")
    func update_clientSamePassword_mapsThrough() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.updateError = .samePassword

        // When / Then
        await #expect(throws: UpdatePasswordError.samePassword) {
            try await useCase.update(newPassword: "newpassword456")
        }
    }

    @Test("UP4. client 拋 .weakPassword → throws .weakPassword")
    func update_clientWeakPassword_mapsThrough() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.updateError = .weakPassword

        // When / Then
        await #expect(throws: UpdatePasswordError.weakPassword) {
            try await useCase.update(newPassword: "newpassword456")
        }
    }

    @Test("UP5. client 拋 .network → throws .network")
    func update_clientNetworkError_mapsThrough() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.updateError = .network

        // When / Then
        await #expect(throws: UpdatePasswordError.network) {
            try await useCase.update(newPassword: "newpassword456")
        }
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

struct SignInUseCaseTests {

    private func makeSUT() -> (useCase: SignInUseCase, clientFake: FakeAuthSessionClient) {
        let clientFake = FakeAuthSessionClient()
        let useCase = SignInUseCase(authSessionClient: clientFake)
        return (useCase, clientFake)
    }

    @Test("SI1. email 前後空白 + client 成功 → 不 throw；client called 1 次、email 已 trim")
    func signIn_validInputs_callsClientWithTrimmedEmail() async throws {
        // Given
        let (useCase, clientFake) = makeSUT()

        // When
        try await useCase.signIn(email: "  x@y.com  ", password: "password123")

        // Then
        #expect(clientFake.signInCount == 1)
        #expect(clientFake.lastSignInEmail == "x@y.com")
        #expect(clientFake.lastSignInPassword == "password123")
    }

    @Test("SI2. client 拋 .invalidCredentials → throws SignInError.invalidCredentials")
    func signIn_clientInvalidCredentials_mapsToInvalidCredentials() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.signInError = .invalidCredentials

        // When / Then
        await #expect(throws: SignInError.invalidCredentials) {
            try await useCase.signIn(email: "x@y.com", password: "password123")
        }
    }

    @Test("SI3. client 拋 .emailNotConfirmed → throws SignInError.emailNotConfirmed")
    func signIn_clientEmailNotConfirmed_mapsToEmailNotConfirmed() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.signInError = .emailNotConfirmed

        // When / Then
        await #expect(throws: SignInError.emailNotConfirmed) {
            try await useCase.signIn(email: "x@y.com", password: "password123")
        }
    }

    @Test("SI4. client 拋 .network → throws SignInError.network")
    func signIn_clientNetworkError_mapsToNetwork() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.signInError = .network

        // When / Then
        await #expect(throws: SignInError.network) {
            try await useCase.signIn(email: "x@y.com", password: "password123")
        }
    }

    @Test("SI5. client 拋 .generic → throws SignInError.generic")
    func signIn_clientGenericError_mapsToGeneric() async {
        // Given
        let (useCase, clientFake) = makeSUT()
        clientFake.signInError = .generic

        // When / Then
        await #expect(throws: SignInError.generic) {
            try await useCase.signIn(email: "x@y.com", password: "password123")
        }
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

struct DeleteAccountUseCaseTests {

    private func makeSUT() -> (
        useCase: DeleteAccountUseCase,
        accountFake: FakeAccountRepository
    ) {
        let accountFake = FakeAccountRepository()
        let useCase = DeleteAccountUseCase(accountRepository: accountFake)
        return (useCase, accountFake)
    }

    @Test("DEL1. repo.deleteAccount 成功 → usecase 不 throw；repo called 1 次")
    func deleteAccount_succeeds_callsRepoOnce() async throws {
        // Given
        let (useCase, accountFake) = makeSUT()

        // When
        try await useCase.deleteAccount()

        // Then
        #expect(accountFake.deleteCount == 1)
    }

    @Test("DEL2. repo.deleteAccount 拋 .persistenceFailure / .network → 分別透傳")
    func deleteAccount_repoFails_passesThrough() async {
        // Given: persistenceFailure
        let (useCase1, fake1) = makeSUT()
        fake1.deleteError = .persistenceFailure

        // When / Then
        await #expect(throws: DeleteAccountError.persistenceFailure) {
            try await useCase1.deleteAccount()
        }

        // Given: network
        let (useCase2, fake2) = makeSUT()
        fake2.deleteError = .network

        // When / Then
        await #expect(throws: DeleteAccountError.network) {
            try await useCase2.deleteAccount()
        }
    }
}

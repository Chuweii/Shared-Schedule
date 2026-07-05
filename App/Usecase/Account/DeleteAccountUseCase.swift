import Foundation

nonisolated struct DeleteAccountUseCase: DeleteAccountUseCaseProtocol {
    let accountRepository: any AccountRepositoryProtocol

    init(accountRepository: any AccountRepositoryProtocol) {
        self.accountRepository = accountRepository
    }

    func deleteAccount() async throws(DeleteAccountError) {
        try await accountRepository.deleteAccount()
    }
}

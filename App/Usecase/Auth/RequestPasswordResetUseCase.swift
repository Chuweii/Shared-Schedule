import Foundation

nonisolated struct RequestPasswordResetUseCase: RequestPasswordResetUseCaseProtocol {
    let authPasswordResetClient: any AuthPasswordResetClientProtocol

    init(authPasswordResetClient: any AuthPasswordResetClientProtocol) {
        self.authPasswordResetClient = authPasswordResetClient
    }

    func request(email: String) async throws(RequestPasswordResetError) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else { throw .emptyEmail }
        do {
            try await authPasswordResetClient.requestPasswordReset(email: trimmedEmail)
        } catch {
            switch error {
            case .rateLimited: throw .rateLimited
            case .network: throw .network
            case .generic: throw .generic
            }
        }
    }
}

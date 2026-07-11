import Foundation

nonisolated struct UpdatePasswordUseCase: UpdatePasswordUseCaseProtocol {
    let authPasswordResetClient: any AuthPasswordResetClientProtocol

    init(authPasswordResetClient: any AuthPasswordResetClientProtocol) {
        self.authPasswordResetClient = authPasswordResetClient
    }

    func update(newPassword: String) async throws(UpdatePasswordError) {
        guard newPassword.count >= 6 else { throw .shortPassword }
        do {
            try await authPasswordResetClient.updatePassword(newPassword)
        } catch {
            switch error {
            case .samePassword: throw .samePassword
            case .weakPassword: throw .weakPassword
            case .network: throw .network
            case .generic: throw .generic
            }
        }
    }
}

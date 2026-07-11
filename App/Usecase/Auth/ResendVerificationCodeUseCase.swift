import Foundation

nonisolated struct ResendVerificationCodeUseCase: ResendVerificationCodeUseCaseProtocol {
    let authSessionClient: any AuthSessionClientProtocol

    init(authSessionClient: any AuthSessionClientProtocol) {
        self.authSessionClient = authSessionClient
    }

    func resend(email: String) async throws(ResendVerificationCodeError) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await authSessionClient.resendSignUpConfirmation(email: trimmedEmail)
        } catch {
            switch error {
            case .rateLimited: throw .rateLimited
            case .network: throw .network
            case .generic: throw .generic
            }
        }
    }
}

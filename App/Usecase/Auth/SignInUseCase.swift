import Foundation

nonisolated struct SignInUseCase: SignInUseCaseProtocol {
    let authSessionClient: any AuthSessionClientProtocol

    init(authSessionClient: any AuthSessionClientProtocol) {
        self.authSessionClient = authSessionClient
    }

    func signIn(email: String, password: String) async throws(SignInError) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await authSessionClient.signIn(email: trimmedEmail, password: password)
        } catch {
            switch error {
            case .emailNotConfirmed: throw .emailNotConfirmed
            case .invalidCredentials: throw .invalidCredentials
            case .network: throw .network
            case .generic: throw .generic
            }
        }
    }
}

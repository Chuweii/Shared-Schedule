import Foundation

nonisolated struct CompleteSignUpUseCase: CompleteSignUpUseCaseProtocol {
    let authSignUpClient: any AuthSignUpClientProtocol

    init(authSignUpClient: any AuthSignUpClientProtocol) {
        self.authSignUpClient = authSignUpClient
    }

    func completeSignUp(email: String, password: String, displayName: String)
        async throws(CompleteSignUpError)
    {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedEmail.isEmpty else { throw .invalidEmail }
        guard password.count >= 6 else { throw .invalidPassword }
        guard !trimmedDisplayName.isEmpty, trimmedDisplayName.count <= 50
        else { throw .invalidDisplayName }

        do {
            try await authSignUpClient.signUp(
                email: trimmedEmail,
                password: password,
                displayName: trimmedDisplayName
            )
        } catch AuthSignUpError.userAlreadyExists {
            throw .userAlreadyExists
        } catch AuthSignUpError.weakPassword {
            throw .weakPassword
        } catch AuthSignUpError.network {
            throw .network
        } catch {
            throw .generic
        }
    }
}

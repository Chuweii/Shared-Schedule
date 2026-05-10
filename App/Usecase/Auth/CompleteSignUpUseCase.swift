import Foundation

nonisolated struct CompleteSignUpUseCase: CompleteSignUpUseCaseProtocol {
    let authSignUpClient: any AuthSignUpClientProtocol
    let userProfileRepository: any UserProfileRepositoryProtocol

    init(
        authSignUpClient: any AuthSignUpClientProtocol,
        userProfileRepository: any UserProfileRepositoryProtocol
    ) {
        self.authSignUpClient = authSignUpClient
        self.userProfileRepository = userProfileRepository
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
            try await authSignUpClient.signUp(email: trimmedEmail, password: password)
        } catch AuthSignUpError.userAlreadyExists {
            throw .userAlreadyExists
        } catch AuthSignUpError.weakPassword {
            throw .weakPassword
        } catch AuthSignUpError.network {
            throw .network
        } catch {
            throw .generic
        }

        do {
            _ = try await userProfileRepository.create(displayName: trimmedDisplayName)
        } catch UserProfileError.alreadyExists {
            // Retry race after a previous partial-failure: treat as success.
            return
        } catch UserProfileError.invalidDisplayName {
            // Server-side rejected length even though client passed; surface
            // distinctly so VM doesn't silently call it a partial failure.
            throw .invalidDisplayName
        } catch {
            throw .partialFailure
        }
    }
}

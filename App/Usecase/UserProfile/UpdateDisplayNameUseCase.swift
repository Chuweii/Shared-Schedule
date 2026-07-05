import Foundation

nonisolated struct UpdateDisplayNameUseCase: UpdateDisplayNameUseCaseProtocol {
    let userProfileRepository: any UserProfileRepositoryProtocol

    init(userProfileRepository: any UserProfileRepositoryProtocol) {
        self.userProfileRepository = userProfileRepository
    }

    func updateDisplayName(_ displayName: String)
        async throws(UpdateDisplayNameError) -> UserProfile
    {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else {
            throw .invalidDisplayName
        }

        do {
            return try await userProfileRepository.update(displayName: trimmed)
        } catch UserProfileError.invalidDisplayName {
            // Server rejected length even though client passed — surface
            // distinctly so the VM shows the length message, not a generic one.
            throw .invalidDisplayName
        } catch {
            throw .persistenceFailure
        }
    }
}

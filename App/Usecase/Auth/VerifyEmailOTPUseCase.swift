import Foundation

nonisolated struct VerifyEmailOTPUseCase: VerifyEmailOTPUseCaseProtocol {
    let authSessionClient: any AuthSessionClientProtocol
    let userProfileRepository: any UserProfileRepositoryProtocol

    init(
        authSessionClient: any AuthSessionClientProtocol,
        userProfileRepository: any UserProfileRepositoryProtocol
    ) {
        self.authSessionClient = authSessionClient
        self.userProfileRepository = userProfileRepository
    }

    func verify(email: String, code: String, displayName: String?)
        async throws(VerifyEmailOTPError)
    {
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw .invalidCodeFormat
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            try await authSessionClient.verifySignUpOTP(email: trimmedEmail, token: code)
        } catch {
            switch error {
            case .invalidOrExpiredCode: throw .invalidOrExpiredCode
            case .rateLimited: throw .rateLimited
            case .network: throw .network
            case .generic: throw .generic
            }
        }

        // Best-effort: the user is verified and signed in at this point,
        // so a profile-create failure must not fail the flow — the email
        // fallback + Settings rename cover it (see spec.md D1).
        if let displayName {
            let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            _ = try? await userProfileRepository.create(displayName: trimmedDisplayName)
        }
    }
}

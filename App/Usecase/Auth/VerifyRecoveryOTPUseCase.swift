import Foundation

nonisolated struct VerifyRecoveryOTPUseCase: VerifyRecoveryOTPUseCaseProtocol {
    let authPasswordResetClient: any AuthPasswordResetClientProtocol

    init(authPasswordResetClient: any AuthPasswordResetClientProtocol) {
        self.authPasswordResetClient = authPasswordResetClient
    }

    func verify(email: String, code: String) async throws(VerifyRecoveryOTPError) {
        guard code.count == 6, code.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            throw .invalidCodeFormat
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await authPasswordResetClient.verifyRecoveryOTP(
                email: trimmedEmail,
                token: code
            )
        } catch {
            switch error {
            case .invalidOrExpiredCode: throw .invalidOrExpiredCode
            case .rateLimited: throw .rateLimited
            case .network: throw .network
            case .generic: throw .generic
            }
        }
    }
}

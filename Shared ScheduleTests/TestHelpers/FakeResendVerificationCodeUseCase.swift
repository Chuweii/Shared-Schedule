import Foundation
@testable import Shared_Schedule

final class FakeResendVerificationCodeUseCase: ResendVerificationCodeUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: ResendVerificationCodeError?

    private(set) var callCount = 0
    private(set) var lastEmail: String?

    func resend(email: String) async throws(ResendVerificationCodeError) {
        callCount += 1
        lastEmail = email
        if let errorToThrow { throw errorToThrow }
    }
}

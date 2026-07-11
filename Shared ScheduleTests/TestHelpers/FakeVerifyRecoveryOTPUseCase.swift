import Foundation
@testable import Shared_Schedule

final class FakeVerifyRecoveryOTPUseCase: VerifyRecoveryOTPUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: VerifyRecoveryOTPError?

    private(set) var callCount = 0
    private(set) var lastEmail: String?
    private(set) var lastCode: String?

    func verify(email: String, code: String) async throws(VerifyRecoveryOTPError) {
        callCount += 1
        lastEmail = email
        lastCode = code
        if let errorToThrow { throw errorToThrow }
    }
}

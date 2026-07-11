import Foundation
@testable import Shared_Schedule

final class FakeVerifyEmailOTPUseCase: VerifyEmailOTPUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: VerifyEmailOTPError?

    private(set) var callCount = 0
    private(set) var lastEmail: String?
    private(set) var lastCode: String?
    private(set) var lastDisplayName: String?

    func verify(email: String, code: String, displayName: String?)
        async throws(VerifyEmailOTPError)
    {
        callCount += 1
        lastEmail = email
        lastCode = code
        lastDisplayName = displayName
        if let errorToThrow { throw errorToThrow }
    }
}

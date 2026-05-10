import Foundation
@testable import Shared_Schedule

final class FakeCompleteSignUpUseCase: CompleteSignUpUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: CompleteSignUpError?

    private(set) var callCount = 0
    private(set) var lastEmail: String?
    private(set) var lastPassword: String?
    private(set) var lastDisplayName: String?

    func completeSignUp(email: String, password: String, displayName: String)
        async throws(CompleteSignUpError)
    {
        callCount += 1
        lastEmail = email
        lastPassword = password
        lastDisplayName = displayName
        if let errorToThrow { throw errorToThrow }
    }
}

import Foundation
@testable import Shared_Schedule

final class FakeSignInUseCase: SignInUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: SignInError?

    private(set) var callCount = 0
    private(set) var lastEmail: String?
    private(set) var lastPassword: String?

    func signIn(email: String, password: String) async throws(SignInError) {
        callCount += 1
        lastEmail = email
        lastPassword = password
        if let errorToThrow { throw errorToThrow }
    }
}

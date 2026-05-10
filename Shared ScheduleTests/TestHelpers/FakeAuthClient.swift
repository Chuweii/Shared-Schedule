import Foundation
@testable import Shared_Schedule

final class FakeAuthClient: AuthSignUpClientProtocol, @unchecked Sendable {
    var signUpError: AuthSignUpError?

    private(set) var signUpCount = 0
    private(set) var lastEmail: String?
    private(set) var lastPassword: String?

    func signUp(email: String, password: String) async throws(AuthSignUpError) {
        signUpCount += 1
        lastEmail = email
        lastPassword = password
        if let signUpError { throw signUpError }
    }
}

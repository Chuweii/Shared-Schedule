import Foundation
@testable import Shared_Schedule

final class FakeAuthClient: AuthSignUpClientProtocol, @unchecked Sendable {
    var signUpError: AuthSignUpError?

    private(set) var signUpCount = 0
    private(set) var lastEmail: String?
    private(set) var lastPassword: String?
    private(set) var lastDisplayName: String?

    func signUp(email: String, password: String, displayName: String)
        async throws(AuthSignUpError)
    {
        signUpCount += 1
        lastEmail = email
        lastPassword = password
        lastDisplayName = displayName
        if let signUpError { throw signUpError }
    }
}

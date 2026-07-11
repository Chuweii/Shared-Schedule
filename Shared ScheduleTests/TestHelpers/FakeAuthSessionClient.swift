import Foundation
@testable import Shared_Schedule

final class FakeAuthSessionClient: AuthSessionClientProtocol, @unchecked Sendable {
    var signInError: AuthSignInError?
    var verifyError: VerifyOTPClientError?
    var resendError: ResendConfirmationError?

    private(set) var signInCount = 0
    private(set) var lastSignInEmail: String?
    private(set) var lastSignInPassword: String?
    private(set) var verifyCount = 0
    private(set) var lastVerifyEmail: String?
    private(set) var lastVerifyToken: String?
    private(set) var resendCount = 0
    private(set) var lastResendEmail: String?

    func signIn(email: String, password: String) async throws(AuthSignInError) {
        signInCount += 1
        lastSignInEmail = email
        lastSignInPassword = password
        if let signInError { throw signInError }
    }

    func verifySignUpOTP(email: String, token: String) async throws(VerifyOTPClientError) {
        verifyCount += 1
        lastVerifyEmail = email
        lastVerifyToken = token
        if let verifyError { throw verifyError }
    }

    func resendSignUpConfirmation(email: String) async throws(ResendConfirmationError) {
        resendCount += 1
        lastResendEmail = email
        if let resendError { throw resendError }
    }
}

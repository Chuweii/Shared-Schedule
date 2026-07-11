import Foundation
@testable import Shared_Schedule

final class FakeAuthPasswordResetClient: AuthPasswordResetClientProtocol, @unchecked Sendable {
    var requestError: PasswordResetRequestError?
    var verifyError: VerifyOTPClientError?
    var updateError: UpdatePasswordClientError?

    private(set) var requestCount = 0
    private(set) var lastRequestEmail: String?
    private(set) var verifyCount = 0
    private(set) var lastVerifyEmail: String?
    private(set) var lastVerifyToken: String?
    private(set) var updateCount = 0
    private(set) var lastNewPassword: String?

    func requestPasswordReset(email: String) async throws(PasswordResetRequestError) {
        requestCount += 1
        lastRequestEmail = email
        if let requestError { throw requestError }
    }

    func verifyRecoveryOTP(email: String, token: String) async throws(VerifyOTPClientError) {
        verifyCount += 1
        lastVerifyEmail = email
        lastVerifyToken = token
        if let verifyError { throw verifyError }
    }

    func updatePassword(_ newPassword: String) async throws(UpdatePasswordClientError) {
        updateCount += 1
        lastNewPassword = newPassword
        if let updateError { throw updateError }
    }
}

import Foundation
@testable import Shared_Schedule

final class FakeRequestPasswordResetUseCase: RequestPasswordResetUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: RequestPasswordResetError?

    private(set) var callCount = 0
    private(set) var lastEmail: String?

    func request(email: String) async throws(RequestPasswordResetError) {
        callCount += 1
        lastEmail = email
        if let errorToThrow { throw errorToThrow }
    }
}

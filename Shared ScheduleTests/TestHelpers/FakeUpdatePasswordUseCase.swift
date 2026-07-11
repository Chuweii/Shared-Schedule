import Foundation
@testable import Shared_Schedule

final class FakeUpdatePasswordUseCase: UpdatePasswordUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: UpdatePasswordError?

    private(set) var callCount = 0
    private(set) var lastNewPassword: String?

    func update(newPassword: String) async throws(UpdatePasswordError) {
        callCount += 1
        lastNewPassword = newPassword
        if let errorToThrow { throw errorToThrow }
    }
}

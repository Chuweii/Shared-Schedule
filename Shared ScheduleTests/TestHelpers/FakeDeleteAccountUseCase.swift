import Foundation
@testable import Shared_Schedule

final class FakeDeleteAccountUseCase: DeleteAccountUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: DeleteAccountError?

    private(set) var callCount = 0

    func deleteAccount() async throws(DeleteAccountError) {
        callCount += 1
        if let errorToThrow { throw errorToThrow }
    }
}

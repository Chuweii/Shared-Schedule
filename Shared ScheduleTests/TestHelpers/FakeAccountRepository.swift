import Foundation
@testable import Shared_Schedule

final class FakeAccountRepository: AccountRepositoryProtocol, @unchecked Sendable {
    var deleteError: DeleteAccountError?
    private(set) var deleteCount = 0

    func deleteAccount() async throws(DeleteAccountError) {
        deleteCount += 1
        if let deleteError { throw deleteError }
    }
}

import Foundation
@testable import Shared_Schedule

final class FakeUpdateDisplayNameUseCase: UpdateDisplayNameUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: UpdateDisplayNameError?
    var resultToReturn: UserProfile?

    private(set) var callCount = 0
    private(set) var lastDisplayName: String?

    func updateDisplayName(_ displayName: String)
        async throws(UpdateDisplayNameError) -> UserProfile
    {
        callCount += 1
        lastDisplayName = displayName
        if let errorToThrow { throw errorToThrow }
        guard let resultToReturn else { throw .persistenceFailure }
        return resultToReturn
    }
}

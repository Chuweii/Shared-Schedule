import Foundation
@testable import Shared_Schedule

final class FakeRedeemInvitationUseCase: RedeemInvitationUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: Schedule?
    var errorToThrow: InvitationRedemptionError?
    private(set) var callCount = 0
    private(set) var lastToken: InvitationToken?

    func redeemInvitation(token: InvitationToken)
        async throws(InvitationRedemptionError) -> Schedule
    {
        callCount += 1
        lastToken = token
        if let errorToThrow { throw errorToThrow }
        if let resultToReturn { return resultToReturn }
        // No expectation set — surface as persistenceFailure so callers
        // notice they forgot to wire the test double.
        throw .persistenceFailure
    }
}

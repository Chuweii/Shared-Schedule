import Foundation
@testable import Shared_Schedule

/// Test double mirroring InMemoryScheduleRepository's pattern.
final class FakeInvitationRepository: InvitationRepositoryProtocol, @unchecked Sendable {
    private var store: [InvitationID: Invitation] = [:]

    /// Set to make `save` throw — used to drive the persistenceFailure path.
    var saveError: Error?

    /// Set to make `fetchAll` throw — used to drive the persistenceFailure path.
    var fetchAllError: Error?

    /// Set to make `redeem` return this redemption — used for R1 / R6 paths.
    var redeemResultToReturn: InvitationRedemption?

    /// Set to make `redeem` throw this error — used for R2-R5 mapping paths.
    var redeemErrorToThrow: InvitationRedemptionError?

    private(set) var saveCount = 0
    private(set) var redeemCount = 0
    private(set) var lastRedeemedToken: InvitationToken?

    func save(_ invitation: Invitation) async throws {
        saveCount += 1
        if let saveError { throw saveError }
        store[invitation.id] = invitation
    }

    func fetch(id: InvitationID) async throws -> Invitation? {
        store[id]
    }

    func fetchByToken(_ token: InvitationToken) async throws -> Invitation? {
        store.values.first { $0.token == token }
    }

    func fetchAll(for scheduleID: ScheduleID) async throws -> [Invitation] {
        if let fetchAllError { throw fetchAllError }
        return store.values.filter { $0.scheduleID == scheduleID }
    }

    func preload(_ invitations: [Invitation]) {
        for invitation in invitations {
            store[invitation.id] = invitation
        }
    }

    func redeem(token: InvitationToken)
        async throws(InvitationRedemptionError) -> InvitationRedemption
    {
        redeemCount += 1
        lastRedeemedToken = token
        if let redeemErrorToThrow { throw redeemErrorToThrow }
        if let redeemResultToReturn { return redeemResultToReturn }
        // No expectation set — surface as persistenceFailure so callers
        // notice they forgot to wire the test double.
        throw .persistenceFailure
    }
}

enum FakeInvitationRepositoryError: Error {
    case forced
}

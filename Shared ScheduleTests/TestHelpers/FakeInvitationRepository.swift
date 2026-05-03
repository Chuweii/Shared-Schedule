import Foundation
@testable import Shared_Schedule

/// Test double mirroring InMemoryScheduleRepository's pattern.
final class FakeInvitationRepository: InvitationRepositoryProtocol, @unchecked Sendable {
    private var store: [InvitationID: Invitation] = [:]

    /// Set to make `save` throw — used to drive the persistenceFailure path.
    var saveError: Error?

    /// Set to make `fetchAll` throw — used to drive the persistenceFailure path.
    var fetchAllError: Error?

    private(set) var saveCount = 0

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
}

enum FakeInvitationRepositoryError: Error {
    case forced
}

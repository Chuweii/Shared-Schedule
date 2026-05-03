/// Used by `AppDependencies.live` for SwiftUI previews. Production code path
/// (RootView) wires `SupabaseInvitationRepository` directly.
nonisolated final class InMemoryInvitationRepository: InvitationRepositoryProtocol, @unchecked Sendable {
    private var store: [InvitationID: Invitation] = [:]

    func save(_ invitation: Invitation) async throws {
        store[invitation.id] = invitation
    }

    func fetch(id: InvitationID) async throws -> Invitation? {
        store[id]
    }

    func fetchByToken(_ token: InvitationToken) async throws -> Invitation? {
        store.values.first { $0.token == token }
    }

    func fetchAll(for scheduleID: ScheduleID) async throws -> [Invitation] {
        store.values
            .filter { $0.scheduleID == scheduleID }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func redeem(token: InvitationToken)
        async throws(InvitationRedemptionError) -> InvitationRedemption
    {
        // Redemption requires the Postgres RPC and a real auth identity;
        // it has no meaningful in-memory equivalent. Previews that exercise
        // the submit path should wire `FakeRedeemInvitationUseCase` at the
        // ViewModel boundary instead.
        throw .persistenceFailure
    }
}

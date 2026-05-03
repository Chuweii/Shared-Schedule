protocol InvitationRepositoryProtocol: Sendable {
    func save(_ invitation: Invitation) async throws
    func fetch(id: InvitationID) async throws -> Invitation?
    func fetchByToken(_ token: InvitationToken) async throws -> Invitation?
    func fetchAll(for scheduleID: ScheduleID) async throws -> [Invitation]

    /// Atomically validate the token, guard against self/duplicate
    /// redemption, and create a `memberships` row for the current user.
    /// Backed by Postgres `redeem_invitation` RPC; Supabase impl maps the
    /// RPC's `RAISE EXCEPTION` codes to typed `InvitationRedemptionError`.
    func redeem(token: InvitationToken)
        async throws(InvitationRedemptionError) -> InvitationRedemption
}

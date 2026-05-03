import PostgREST
import Auth
import Foundation

final class SupabaseInvitationRepository: InvitationRepositoryProtocol, @unchecked Sendable {

    private func db() async throws -> PostgrestClient {
        let session = try await SupabaseClientProvider.auth.session
        return SupabaseClientProvider.database(accessToken: session.accessToken)
    }

    func save(_ invitation: Invitation) async throws {
        let dto = InvitationMapper.toInsertDTO(invitation)
        try await db()
            .from("invitations")
            .upsert(dto, onConflict: "id")
            .execute()
    }

    func fetch(id: InvitationID) async throws -> Invitation? {
        let dtos: [InvitationDTO] = try await db()
            .from("invitations")
            .select()
            .eq("id", value: id.rawValue)
            .execute()
            .value
        return dtos.first.flatMap(InvitationMapper.toDomain)
    }

    func fetchByToken(_ token: InvitationToken) async throws -> Invitation? {
        let dtos: [InvitationDTO] = try await db()
            .from("invitations")
            .select()
            .eq("token", value: token.rawValue)
            .execute()
            .value
        return dtos.first.flatMap(InvitationMapper.toDomain)
    }

    func fetchAll(for scheduleID: ScheduleID) async throws -> [Invitation] {
        let dtos: [InvitationDTO] = try await db()
            .from("invitations")
            .select()
            .eq("schedule_id", value: scheduleID.rawValue)
            .order("created_at", ascending: false)
            .execute()
            .value
        return dtos.compactMap(InvitationMapper.toDomain)
    }

    func redeem(token: InvitationToken)
        async throws(InvitationRedemptionError) -> InvitationRedemption
    {
        let dtos: [InvitationRedemptionDTO]
        do {
            dtos = try await db()
                .rpc("redeem_invitation", params: ["invitation_token": token.rawValue])
                .execute()
                .value
        } catch let pg as PostgrestError {
            throw Self.mapRedeemError(pg)
        } catch {
            throw .persistenceFailure
        }

        guard let dto = dtos.first,
              let redemption = InvitationMapper.toRedemption(dto)
        else {
            throw .persistenceFailure
        }
        return redemption
    }

    /// Maps the RPC's `RAISE EXCEPTION '<code>'` strings to the typed
    /// Domain enum. PostgREST surfaces the message in
    /// `PostgrestError.localizedDescription` (via `LocalizedError`), which
    /// avoids importing the underscored `_Helpers` module that hosts
    /// `PostgrestError.message`. A substring match is sufficient — and
    /// also robust to the incidental `unhandled_exception` prefix Postgres
    /// adds when no SQLSTATE is set.
    static func mapRedeemError(_ pg: PostgrestError) -> InvitationRedemptionError {
        let message = pg.localizedDescription
        if message.contains("INVALID_TOKEN") { return .invalidToken }
        if message.contains("EXPIRED") { return .expired }
        if message.contains("SELF_REDEMPTION") { return .selfRedemption }
        if message.contains("ALREADY_MEMBER") { return .alreadyMember }
        return .persistenceFailure
    }
}

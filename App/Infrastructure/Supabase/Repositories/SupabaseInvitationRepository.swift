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
}

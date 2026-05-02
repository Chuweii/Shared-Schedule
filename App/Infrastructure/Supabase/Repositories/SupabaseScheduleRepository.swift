import PostgREST
import Auth
import Foundation

final class SupabaseScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {

    private func db() async throws -> PostgrestClient {
        let session = try await SupabaseClientProvider.auth.session
        return SupabaseClientProvider.database(accessToken: session.accessToken)
    }

    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule] {
        let dtos: [ScheduleDTO] = try await db()
            .from("schedules")
            .select("*, availability_rules(*), availability_windows(*)")
            .eq("owner_id", value: ownerID.rawValue)
            .execute()
            .value
        return dtos.map(ScheduleMapper.toDomain)
    }

    func fetch(id: ScheduleID) async throws -> Schedule? {
        let dtos: [ScheduleDTO] = try await db()
            .from("schedules")
            .select("*, availability_rules(*), availability_windows(*)")
            .eq("id", value: id.rawValue)
            .execute()
            .value
        return dtos.first.map(ScheduleMapper.toDomain)
    }

    func save(_ schedule: Schedule) async throws {
        let client = try await db()

        // 1. Upsert the schedule row
        let scheduleDTO = ScheduleMapper.toInsertDTO(schedule)
        try await client
            .from("schedules")
            .upsert(scheduleDTO, onConflict: "id")
            .execute()

        // 2. Delete existing rules, then re-insert current ones
        try await client
            .from("availability_rules")
            .delete()
            .eq("schedule_id", value: schedule.id.rawValue)
            .execute()

        let ruleDTOs = ScheduleMapper.toRuleInsertDTOs(schedule)
        if !ruleDTOs.isEmpty {
            try await client
                .from("availability_rules")
                .insert(ruleDTOs)
                .execute()
        }

        // 3. Delete existing windows, then re-insert current ones
        try await client
            .from("availability_windows")
            .delete()
            .eq("schedule_id", value: schedule.id.rawValue)
            .execute()

        let windowDTOs = ScheduleMapper.toWindowInsertDTOs(schedule)
        if !windowDTOs.isEmpty {
            try await client
                .from("availability_windows")
                .insert(windowDTOs)
                .execute()
        }
    }
}

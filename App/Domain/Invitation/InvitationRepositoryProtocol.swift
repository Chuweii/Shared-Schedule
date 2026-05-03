protocol InvitationRepositoryProtocol: Sendable {
    func save(_ invitation: Invitation) async throws
    func fetch(id: InvitationID) async throws -> Invitation?
    func fetchByToken(_ token: InvitationToken) async throws -> Invitation?
    func fetchAll(for scheduleID: ScheduleID) async throws -> [Invitation]
}

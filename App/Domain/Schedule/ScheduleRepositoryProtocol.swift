protocol ScheduleRepositoryProtocol: Sendable {
    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule]
    func fetch(id: ScheduleID) async throws -> Schedule?
    func save(_ schedule: Schedule) async throws
}

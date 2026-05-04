protocol ScheduleRepositoryProtocol: Sendable {
    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule]

    /// Schedules where `userID` has a membership row (i.e. joined as a student),
    /// excluding schedules they own. Subject to the current auth context's
    /// visibility — callers should pass the current user's id.
    func fetchAll(memberOf userID: UserID) async throws -> [Schedule]

    func fetch(id: ScheduleID) async throws -> Schedule?
    func save(_ schedule: Schedule) async throws
}

nonisolated final class InMemoryScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {
    private var store: [ScheduleID: Schedule] = [:]
    private var memberships: Set<MembershipPair> = []

    private struct MembershipPair: Hashable {
        let scheduleID: ScheduleID
        let userID: UserID
    }

    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule] {
        store.values.filter { $0.ownerID == ownerID }
    }

    func fetchAll(memberOf userID: UserID) async throws -> [Schedule] {
        let ids = memberships.filter { $0.userID == userID }.map(\.scheduleID)
        return ids.compactMap { store[$0] }
    }

    func fetch(id: ScheduleID) async throws -> Schedule? {
        store[id]
    }

    func save(_ schedule: Schedule) async throws {
        store[schedule.id] = schedule
    }

    func addMembership(scheduleID: ScheduleID, userID: UserID) {
        memberships.insert(.init(scheduleID: scheduleID, userID: userID))
    }
}

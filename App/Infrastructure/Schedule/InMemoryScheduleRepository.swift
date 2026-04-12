nonisolated final class InMemoryScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {
    private var store: [ScheduleID: Schedule] = [:]

    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule] {
        store.values.filter { $0.ownerID == ownerID }
    }

    func fetch(id: ScheduleID) async throws -> Schedule? {
        store[id]
    }

    func save(_ schedule: Schedule) async throws {
        store[schedule.id] = schedule
    }
}

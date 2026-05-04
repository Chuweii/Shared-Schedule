protocol ListJoinedSchedulesUseCaseProtocol: Sendable {
    func listJoinedSchedules() async throws -> [Schedule]
}

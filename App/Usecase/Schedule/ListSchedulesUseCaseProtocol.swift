protocol ListSchedulesUseCaseProtocol: Sendable {
    func listSchedules() async throws -> [Schedule]
}

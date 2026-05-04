nonisolated struct ListJoinedSchedulesUseCase: ListJoinedSchedulesUseCaseProtocol {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func listJoinedSchedules() async throws -> [Schedule] {
        try await repository.fetchAll(memberOf: currentUserProvider.currentUser.id)
    }
}

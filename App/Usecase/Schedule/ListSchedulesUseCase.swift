nonisolated struct ListSchedulesUseCase: ListSchedulesUseCaseProtocol {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func listSchedules() async throws -> [Schedule] {
        try await repository.fetchAll(ownedBy: currentUserProvider.currentUser.id)
    }
}

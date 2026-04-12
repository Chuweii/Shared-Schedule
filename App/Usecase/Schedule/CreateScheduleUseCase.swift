import Foundation

nonisolated struct CreateScheduleUseCase: CreateScheduleUseCaseProtocol {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval
    ) async throws(CreateScheduleError) -> Schedule {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .blankTitle }

        let schedule = Schedule(
            ownerID: currentUserProvider.currentUser.id,
            title: trimmed,
            minWindowDuration: minWindowDuration
        )

        do {
            try await repository.save(schedule)
        } catch {
            preconditionFailure("Repository.save failed unexpectedly: \(error)")
        }

        return schedule
    }
}

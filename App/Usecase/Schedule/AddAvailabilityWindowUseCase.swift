import Foundation

nonisolated struct AddAvailabilityWindowUseCase: AddAvailabilityWindowUseCaseProtocol {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func addWindow(
        to scheduleID: ScheduleID,
        start: Date,
        end: Date
    ) async throws(ScheduleMutationError) -> Schedule {
        guard var schedule = try await fetchSchedule(id: scheduleID) else {
            throw .scheduleNotFound
        }
        guard schedule.ownerID == currentUserProvider.currentUser.id else {
            throw .notOwner
        }

        do {
            try schedule.addWindow(start: start, end: end)
        } catch {
            throw .scheduleError(error)
        }

        do {
            try await repository.save(schedule)
        } catch {
            throw .repositoryFailure
        }

        return schedule
    }

    private func fetchSchedule(id: ScheduleID) async throws(ScheduleMutationError) -> Schedule? {
        do {
            return try await repository.fetch(id: id)
        } catch {
            throw .repositoryFailure
        }
    }
}

nonisolated struct RemoveAvailabilityWindowUseCase: RemoveAvailabilityWindowUseCaseProtocol {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func removeWindow(
        _ windowID: AvailabilityWindowID,
        from scheduleID: ScheduleID
    ) async throws(ScheduleMutationError) -> Schedule {
        guard var schedule = try await fetchSchedule(id: scheduleID) else {
            throw .scheduleNotFound
        }
        guard schedule.ownerID == currentUserProvider.currentUser.id else {
            throw .notOwner
        }

        schedule.removeWindow(id: windowID)

        do {
            try await repository.save(schedule)
        } catch {
            preconditionFailure("Repository.save failed: \(error)")
        }

        return schedule
    }

    private func fetchSchedule(id: ScheduleID) async throws(ScheduleMutationError) -> Schedule? {
        do {
            return try await repository.fetch(id: id)
        } catch {
            preconditionFailure("Repository.fetch failed: \(error)")
        }
    }
}

import Foundation

nonisolated struct CreateScheduleUseCase: CreateScheduleUseCaseProtocol {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval,
        ruleTemplate: AvailabilityRuleTemplate?
    ) async throws(CreateScheduleError) -> Schedule {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .blankTitle }

        guard let template = ruleTemplate, !template.weekdays.isEmpty else {
            throw .noWeekdaysSelected
        }

        var schedule = Schedule(
            ownerID: currentUserProvider.currentUser.id,
            title: trimmed,
            minWindowDuration: minWindowDuration
        )

        for weekday in template.weekdays.sorted(by: { $0.rawValue < $1.rawValue }) {
            do {
                try schedule.addRule(
                    weekday: weekday,
                    startTime: template.startTime,
                    endTime: template.endTime
                )
            } catch {
                preconditionFailure("addRule failed for \(weekday): \(error)")
            }
        }

        do {
            try await repository.save(schedule)
        } catch {
            throw .repositoryFailure
        }

        return schedule
    }
}

import Foundation
@testable import Shared_Schedule

final class FakeCreateScheduleUseCase: CreateScheduleUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: Schedule?
    var errorToThrow: CreateScheduleError?

    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval,
        ruleTemplate: AvailabilityRuleTemplate?
    ) async throws(CreateScheduleError) -> Schedule {
        if let error = errorToThrow { throw error }
        if let result = resultToReturn { return result }

        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: title,
            minWindowDuration: minWindowDuration
        )
        if let template = ruleTemplate {
            for weekday in template.weekdays {
                try! schedule.addRule(
                    weekday: weekday,
                    startTime: template.startTime,
                    endTime: template.endTime
                )
            }
        }
        return schedule
    }
}

import Foundation

protocol CreateScheduleUseCaseProtocol: Sendable {
    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval,
        ruleTemplate: AvailabilityRuleTemplate?
    ) async throws(CreateScheduleError) -> Schedule
}

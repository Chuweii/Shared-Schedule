import Foundation

protocol CreateScheduleUseCaseProtocol: Sendable {
    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval
    ) async throws(CreateScheduleError) -> Schedule
}

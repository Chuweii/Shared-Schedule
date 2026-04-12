import Foundation

protocol AddAvailabilityWindowUseCaseProtocol: Sendable {
    func addWindow(
        to scheduleID: ScheduleID,
        start: Date,
        end: Date
    ) async throws(ScheduleMutationError) -> Schedule
}

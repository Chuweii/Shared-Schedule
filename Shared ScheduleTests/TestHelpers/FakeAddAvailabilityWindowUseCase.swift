import Foundation
@testable import Shared_Schedule

final class FakeAddAvailabilityWindowUseCase: AddAvailabilityWindowUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: Schedule?
    var errorToThrow: ScheduleMutationError?

    func addWindow(
        to scheduleID: ScheduleID,
        start: Date,
        end: Date
    ) async throws(ScheduleMutationError) -> Schedule {
        if let error = errorToThrow { throw error }
        if let result = resultToReturn { return result }

        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "Test")
        try! schedule.addWindow(start: start, end: end)
        return schedule
    }
}

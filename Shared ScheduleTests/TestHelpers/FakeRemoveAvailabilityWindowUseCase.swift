import Foundation
@testable import Shared_Schedule

final class FakeRemoveAvailabilityWindowUseCase: RemoveAvailabilityWindowUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: Schedule?
    var errorToThrow: ScheduleMutationError?

    func removeWindow(
        _ windowID: AvailabilityWindowID,
        from scheduleID: ScheduleID
    ) async throws(ScheduleMutationError) -> Schedule {
        if let error = errorToThrow { throw error }
        if let result = resultToReturn { return result }
        return Schedule(ownerID: UserID("teacher-001"), title: "Test")
    }
}

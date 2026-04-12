import Foundation
@testable import Shared_Schedule

final class FakeCreateScheduleUseCase: CreateScheduleUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: Schedule?
    var errorToThrow: CreateScheduleError?

    func createSchedule(
        title: String,
        minWindowDuration: TimeInterval
    ) async throws(CreateScheduleError) -> Schedule {
        if let error = errorToThrow { throw error }
        return resultToReturn ?? Schedule(
            ownerID: UserID("teacher-001"),
            title: title,
            minWindowDuration: minWindowDuration
        )
    }
}

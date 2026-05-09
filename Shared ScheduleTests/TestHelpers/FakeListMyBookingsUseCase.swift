import Foundation
@testable import Shared_Schedule

final class FakeListMyBookingsUseCase: ListMyBookingsUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: [Booking] = []
    var errorToThrow: ListMyBookingsError?

    private(set) var callCount = 0
    private(set) var lastScheduleID: ScheduleID?

    func listMyBookings(scheduleID: ScheduleID)
        async throws(ListMyBookingsError) -> [Booking]
    {
        callCount += 1
        lastScheduleID = scheduleID
        if let errorToThrow { throw errorToThrow }
        return resultToReturn
    }
}

import Foundation
@testable import Shared_Schedule

final class FakeListOthersBookingsUseCase: ListOthersBookingsUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: [BookedSlot] = []
    var errorToThrow: ListOthersBookingsError?

    private(set) var callCount = 0
    private(set) var lastScheduleID: ScheduleID?

    func listOthersBookings(scheduleID: ScheduleID)
        async throws(ListOthersBookingsError) -> [BookedSlot]
    {
        callCount += 1
        lastScheduleID = scheduleID
        if let errorToThrow { throw errorToThrow }
        return resultToReturn
    }
}

import Foundation
@testable import Shared_Schedule

final class FakeListAllBookingsForOwnerUseCase: ListAllBookingsForOwnerUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: [OwnerBooking] = []
    var errorToThrow: ListAllBookingsForOwnerError?

    private(set) var callCount = 0
    private(set) var lastScheduleID: ScheduleID?

    func listAllBookingsForOwner(scheduleID: ScheduleID)
        async throws(ListAllBookingsForOwnerError) -> [OwnerBooking]
    {
        callCount += 1
        lastScheduleID = scheduleID
        if let errorToThrow { throw errorToThrow }
        return resultToReturn
    }
}

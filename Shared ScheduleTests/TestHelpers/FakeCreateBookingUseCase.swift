import Foundation
@testable import Shared_Schedule

final class FakeCreateBookingUseCase: CreateBookingUseCaseProtocol, @unchecked Sendable {
    /// Booking returned on success. Tests usually hand-construct the
    /// expected Booking with the desired startsAt/endsAt to validate the
    /// ViewModel's state-merging logic.
    var resultToReturn: Booking?
    var errorToThrow: CreateBookingError?

    private(set) var callCount = 0
    private(set) var lastScheduleID: ScheduleID?
    private(set) var lastSlot: ComputedSlot?

    func createBooking(scheduleID: ScheduleID, slot: ComputedSlot)
        async throws(CreateBookingError) -> Booking
    {
        callCount += 1
        lastScheduleID = scheduleID
        lastSlot = slot
        if let errorToThrow { throw errorToThrow }
        if let resultToReturn { return resultToReturn }
        throw .persistenceFailure
    }
}

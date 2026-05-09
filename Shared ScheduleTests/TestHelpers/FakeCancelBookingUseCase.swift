import Foundation
@testable import Shared_Schedule

final class FakeCancelBookingUseCase: CancelBookingUseCaseProtocol, @unchecked Sendable {
    var errorToThrow: CancelBookingError?

    private(set) var callCount = 0
    private(set) var lastBookingID: BookingID?

    func cancelBooking(_ bookingID: BookingID) async throws(CancelBookingError) {
        callCount += 1
        lastBookingID = bookingID
        if let errorToThrow { throw errorToThrow }
    }
}

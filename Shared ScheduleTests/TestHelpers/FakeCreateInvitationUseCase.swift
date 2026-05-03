import Foundation
@testable import Shared_Schedule

final class FakeCreateInvitationUseCase: CreateInvitationUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: Invitation?
    var errorToThrow: CreateInvitationError?
    private(set) var callCount = 0
    private(set) var lastScheduleID: ScheduleID?

    func createInvitation(scheduleID: ScheduleID)
        async throws(CreateInvitationError) -> Invitation
    {
        callCount += 1
        lastScheduleID = scheduleID
        if let errorToThrow { throw errorToThrow }
        if let resultToReturn { return resultToReturn }

        let now = Date()
        do {
            return try Invitation(
                scheduleID: scheduleID,
                expiresAt: now.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: now
            )
        } catch {
            preconditionFailure("Default invitation construction should never fail: \(error)")
        }
    }
}

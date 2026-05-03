@testable import Shared_Schedule

final class FakeListInvitationsUseCase: ListInvitationsUseCaseProtocol, @unchecked Sendable {
    var resultToReturn: [Invitation] = []
    var errorToThrow: ListInvitationsError?
    private(set) var callCount = 0
    private(set) var lastScheduleID: ScheduleID?

    func listInvitations(for scheduleID: ScheduleID)
        async throws(ListInvitationsError) -> [Invitation]
    {
        callCount += 1
        lastScheduleID = scheduleID
        if let errorToThrow { throw errorToThrow }
        return resultToReturn
    }
}

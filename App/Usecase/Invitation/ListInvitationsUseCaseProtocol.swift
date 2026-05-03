protocol ListInvitationsUseCaseProtocol: Sendable {
    func listInvitations(for scheduleID: ScheduleID)
        async throws(ListInvitationsError) -> [Invitation]
}

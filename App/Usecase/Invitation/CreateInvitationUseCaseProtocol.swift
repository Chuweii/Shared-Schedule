protocol CreateInvitationUseCaseProtocol: Sendable {
    func createInvitation(scheduleID: ScheduleID)
        async throws(CreateInvitationError) -> Invitation
}

nonisolated struct RedeemInvitationUseCase: RedeemInvitationUseCaseProtocol {
    let invitationRepository: any InvitationRepositoryProtocol
    let scheduleRepository: any ScheduleRepositoryProtocol

    init(
        invitationRepository: any InvitationRepositoryProtocol,
        scheduleRepository: any ScheduleRepositoryProtocol
    ) {
        self.invitationRepository = invitationRepository
        self.scheduleRepository = scheduleRepository
    }

    func redeemInvitation(token: InvitationToken)
        async throws(InvitationRedemptionError) -> Schedule
    {
        let redemption = try await invitationRepository.redeem(token: token)

        let scheduleOpt: Schedule?
        do {
            scheduleOpt = try await scheduleRepository.fetch(id: redemption.scheduleID)
        } catch {
            throw .persistenceFailure
        }

        guard let schedule = scheduleOpt else { throw .persistenceFailure }
        return schedule
    }
}

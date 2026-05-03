import Foundation

nonisolated struct CreateInvitationUseCase: CreateInvitationUseCaseProtocol {
    let scheduleRepository: any ScheduleRepositoryProtocol
    let invitationRepository: any InvitationRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol
    let now: @Sendable () -> Date

    init(
        scheduleRepository: any ScheduleRepositoryProtocol,
        invitationRepository: any InvitationRepositoryProtocol,
        currentUserProvider: any CurrentUserProviderProtocol,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.scheduleRepository = scheduleRepository
        self.invitationRepository = invitationRepository
        self.currentUserProvider = currentUserProvider
        self.now = now
    }

    func createInvitation(scheduleID: ScheduleID)
        async throws(CreateInvitationError) -> Invitation
    {
        let schedule: Schedule?
        do {
            schedule = try await scheduleRepository.fetch(id: scheduleID)
        } catch {
            throw .persistenceFailure
        }

        guard let schedule else { throw .scheduleNotFound }

        guard schedule.ownerID == currentUserProvider.currentUser.id else {
            throw .notOwner
        }

        let createdAt = now()
        let invitation: Invitation
        do {
            invitation = try Invitation(
                scheduleID: scheduleID,
                expiresAt: createdAt.addingTimeInterval(Invitation.defaultExpiryDuration),
                createdAt: createdAt
            )
        } catch {
            // .invalidExpiry shouldn't happen with default expiry duration > 0
            throw .persistenceFailure
        }

        do {
            try await invitationRepository.save(invitation)
        } catch {
            throw .persistenceFailure
        }

        return invitation
    }
}

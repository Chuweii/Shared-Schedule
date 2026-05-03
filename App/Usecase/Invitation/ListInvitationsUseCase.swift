nonisolated struct ListInvitationsUseCase: ListInvitationsUseCaseProtocol {
    let scheduleRepository: any ScheduleRepositoryProtocol
    let invitationRepository: any InvitationRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    func listInvitations(for scheduleID: ScheduleID)
        async throws(ListInvitationsError) -> [Invitation]
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

        do {
            let all = try await invitationRepository.fetchAll(for: scheduleID)
            return all.sorted { $0.createdAt > $1.createdAt }
        } catch {
            throw .persistenceFailure
        }
    }
}

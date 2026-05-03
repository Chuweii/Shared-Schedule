import Foundation

nonisolated struct AppDependencies: Sendable {
    let repository: any ScheduleRepositoryProtocol
    let invitationRepository: any InvitationRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    var createScheduleUseCase: any CreateScheduleUseCaseProtocol {
        CreateScheduleUseCase(repository: repository, currentUserProvider: currentUserProvider)
    }

    var listSchedulesUseCase: any ListSchedulesUseCaseProtocol {
        ListSchedulesUseCase(repository: repository, currentUserProvider: currentUserProvider)
    }

    var createInvitationUseCase: any CreateInvitationUseCaseProtocol {
        CreateInvitationUseCase(
            scheduleRepository: repository,
            invitationRepository: invitationRepository,
            currentUserProvider: currentUserProvider
        )
    }

    var listInvitationsUseCase: any ListInvitationsUseCaseProtocol {
        ListInvitationsUseCase(
            scheduleRepository: repository,
            invitationRepository: invitationRepository,
            currentUserProvider: currentUserProvider
        )
    }

    static let live = AppDependencies(
        repository: InMemoryScheduleRepository(),
        invitationRepository: InMemoryInvitationRepository(),
        currentUserProvider: InMemoryCurrentUserProvider()
    )

}

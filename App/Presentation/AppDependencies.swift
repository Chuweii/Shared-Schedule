import Foundation

nonisolated struct AppDependencies: Sendable {
    let repository: any ScheduleRepositoryProtocol
    let invitationRepository: any InvitationRepositoryProtocol
    let bookingRepository: any BookingRepositoryProtocol
    let userProfileRepository: any UserProfileRepositoryProtocol
    let accountRepository: any AccountRepositoryProtocol
    let authSignUpClient: any AuthSignUpClientProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    var createScheduleUseCase: any CreateScheduleUseCaseProtocol {
        CreateScheduleUseCase(repository: repository, currentUserProvider: currentUserProvider)
    }

    var listSchedulesUseCase: any ListSchedulesUseCaseProtocol {
        ListSchedulesUseCase(repository: repository, currentUserProvider: currentUserProvider)
    }

    var listJoinedSchedulesUseCase: any ListJoinedSchedulesUseCaseProtocol {
        ListJoinedSchedulesUseCase(repository: repository, currentUserProvider: currentUserProvider)
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

    var redeemInvitationUseCase: any RedeemInvitationUseCaseProtocol {
        RedeemInvitationUseCase(
            invitationRepository: invitationRepository,
            scheduleRepository: repository
        )
    }

    var createBookingUseCase: any CreateBookingUseCaseProtocol {
        CreateBookingUseCase(
            scheduleRepository: repository,
            bookingRepository: bookingRepository,
            currentUserProvider: currentUserProvider
        )
    }

    var cancelBookingUseCase: any CancelBookingUseCaseProtocol {
        CancelBookingUseCase(bookingRepository: bookingRepository)
    }

    var listMyBookingsUseCase: any ListMyBookingsUseCaseProtocol {
        ListMyBookingsUseCase(
            bookingRepository: bookingRepository,
            currentUserProvider: currentUserProvider
        )
    }

    var listAllBookingsForOwnerUseCase: any ListAllBookingsForOwnerUseCaseProtocol {
        ListAllBookingsForOwnerUseCase(bookingRepository: bookingRepository)
    }

    var listOthersBookingsUseCase: any ListOthersBookingsUseCaseProtocol {
        ListOthersBookingsUseCase(bookingRepository: bookingRepository)
    }

    var completeSignUpUseCase: any CompleteSignUpUseCaseProtocol {
        CompleteSignUpUseCase(
            authSignUpClient: authSignUpClient,
            userProfileRepository: userProfileRepository
        )
    }

    var updateDisplayNameUseCase: any UpdateDisplayNameUseCaseProtocol {
        UpdateDisplayNameUseCase(userProfileRepository: userProfileRepository)
    }

    var deleteAccountUseCase: any DeleteAccountUseCaseProtocol {
        DeleteAccountUseCase(accountRepository: accountRepository)
    }

    static let live = AppDependencies(
        repository: InMemoryScheduleRepository(),
        invitationRepository: InMemoryInvitationRepository(),
        bookingRepository: InMemoryBookingRepository(),
        userProfileRepository: InMemoryUserProfileRepository(),
        accountRepository: InMemoryAccountRepository(),
        authSignUpClient: InMemoryAuthSignUpClient(),
        currentUserProvider: InMemoryCurrentUserProvider()
    )

}

import Foundation

nonisolated struct AppDependencies: Sendable {
    let repository: any ScheduleRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol

    var createScheduleUseCase: any CreateScheduleUseCaseProtocol {
        CreateScheduleUseCase(repository: repository, currentUserProvider: currentUserProvider)
    }

    var listSchedulesUseCase: any ListSchedulesUseCaseProtocol {
        ListSchedulesUseCase(repository: repository, currentUserProvider: currentUserProvider)
    }

    static let live = AppDependencies(
        repository: InMemoryScheduleRepository(),
        currentUserProvider: InMemoryCurrentUserProvider()
    )

}

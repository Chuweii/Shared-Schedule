/// Outcomes of `ListMyBookingsUseCase`. Lives in Usecase (not Domain)
/// because it is the usecase's own throw — `BookingRepositoryProtocol.fetchAll`
/// throws naked Error, so the repo doesn't need this type.
nonisolated enum ListMyBookingsError: Error, Equatable, Sendable {
    case persistenceFailure
}

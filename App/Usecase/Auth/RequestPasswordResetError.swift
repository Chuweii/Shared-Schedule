/// Outcomes of `RequestPasswordResetUseCase.request`.
nonisolated enum RequestPasswordResetError: Error, Equatable, Sendable {
    /// Pre-flight: email is blank after trimming.
    case emptyEmail
    case rateLimited
    case network
    case generic
}

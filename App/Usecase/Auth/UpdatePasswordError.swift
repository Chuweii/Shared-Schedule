/// Outcomes of `UpdatePasswordUseCase.update`.
nonisolated enum UpdatePasswordError: Error, Equatable, Sendable {
    /// Pre-flight: length < 6 (mirrors `minimum_password_length`).
    case shortPassword
    case samePassword
    case weakPassword
    case network
    case generic
}

/// Outcomes of `VerifyEmailOTPUseCase.verify`.
nonisolated enum VerifyEmailOTPError: Error, Equatable, Sendable {
    /// Pre-flight: code is not exactly 6 ASCII digits.
    case invalidCodeFormat
    case invalidOrExpiredCode
    case rateLimited
    case network
    case generic
}

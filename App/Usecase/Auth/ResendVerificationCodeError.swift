/// Outcomes of `ResendVerificationCodeUseCase.resend`.
nonisolated enum ResendVerificationCodeError: Error, Equatable, Sendable {
    case rateLimited
    case network
    case generic
}

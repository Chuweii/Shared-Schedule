import Foundation

@MainActor
@Observable
final class EmailVerificationViewModel {
    /// Presentation-level error cases. The View maps each case to a
    /// `LocalizedStringKey` so messages follow the in-app language
    /// override (`String(localized:)` resolved here would not).
    enum VerificationError: Equatable {
        case emptyCode
        case invalidCodeFormat
        case invalidOrExpiredCode
        case rateLimited
        case network
        case generic
    }

    let email: String
    /// Non-nil right after sign-up; nil on the deferred-verification
    /// path (profile creation is skipped, Settings rename repairs it).
    let displayName: String?

    var code = ""
    var isLoading = false
    var error: VerificationError?
    /// Client-side resend cooldown; `resend()` is a no-op while > 0.
    var resendSecondsRemaining = 0

    private let verifyEmailOTPUseCase: any VerifyEmailOTPUseCaseProtocol
    private let resendVerificationCodeUseCase: any ResendVerificationCodeUseCaseProtocol
    private let currentUserProvider: any CurrentUserProviderProtocol
    private var countdownTask: Task<Void, Never>?

    init(
        email: String,
        displayName: String?,
        verifyEmailOTPUseCase: any VerifyEmailOTPUseCaseProtocol,
        resendVerificationCodeUseCase: any ResendVerificationCodeUseCaseProtocol,
        currentUserProvider: any CurrentUserProviderProtocol
    ) {
        self.email = email
        self.displayName = displayName
        self.verifyEmailOTPUseCase = verifyEmailOTPUseCase
        self.resendVerificationCodeUseCase = resendVerificationCodeUseCase
        self.currentUserProvider = currentUserProvider
    }

    func verify() async {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            error = .emptyCode
            return
        }
        isLoading = true
        error = nil
        do {
            try await verifyEmailOTPUseCase.verify(
                email: email,
                code: trimmedCode,
                displayName: displayName
            )
            // Success: `.signedIn` has fired and RootView tears this
            // screen down. Patch the cached user's name so the first
            // authenticated session doesn't race the profile insert.
            if let displayName {
                currentUserProvider.updateCachedDisplayName(displayName)
            }
        } catch {
            self.error = Self.describe(error)
        }
        isLoading = false
    }

    func resend() async {
        guard resendSecondsRemaining == 0 else { return }
        do {
            try await resendVerificationCodeUseCase.resend(email: email)
            error = nil
            startCooldown()
        } catch {
            self.error = Self.describeResend(error)
        }
    }

    private func startCooldown() {
        resendSecondsRemaining = 60
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while let self, self.resendSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.resendSecondsRemaining -= 1
            }
        }
    }

    static func describe(_ error: VerifyEmailOTPError) -> VerificationError {
        switch error {
        case .invalidCodeFormat: return .invalidCodeFormat
        case .invalidOrExpiredCode: return .invalidOrExpiredCode
        case .rateLimited: return .rateLimited
        case .network: return .network
        case .generic: return .generic
        }
    }

    static func describeResend(_ error: ResendVerificationCodeError) -> VerificationError {
        switch error {
        case .rateLimited: return .rateLimited
        case .network: return .network
        case .generic: return .generic
        }
    }
}

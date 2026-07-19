import Foundation

@MainActor
@Observable
final class ForgotPasswordViewModel {
    /// The three-step in-app reset flow. `verifyOTP(.recovery)` at step
    /// `enterCode` yields a session (RootView flips underneath the
    /// cover); `done` fires `onComplete`, which dismisses the cover
    /// into the already-authenticated app.
    enum Step: Equatable {
        case enterEmail
        case enterCode
        case newPassword
        case done
    }

    /// Presentation-level error cases. The View maps each case to a
    /// `LocalizedStringKey` so messages follow the in-app language
    /// override (`String(localized:)` resolved here would not).
    enum ResetError: Equatable {
        case emptyEmail
        case emptyCode
        case invalidCodeFormat
        case invalidOrExpiredCode
        case shortPassword
        case samePassword
        case weakPassword
        case rateLimited
        case network
        case generic
    }

    var step: Step = .enterEmail
    var email = ""
    var code = ""
    var newPassword = ""
    var isLoading = false
    var error: ResetError?
    /// Client-side resend cooldown; `resendCode()` is a no-op while > 0.
    var resendSecondsRemaining = 0

    private let requestPasswordResetUseCase: any RequestPasswordResetUseCaseProtocol
    private let verifyRecoveryOTPUseCase: any VerifyRecoveryOTPUseCaseProtocol
    private let updatePasswordUseCase: any UpdatePasswordUseCaseProtocol
    private let onComplete: () -> Void
    private var countdownTask: Task<Void, Never>?

    init(
        requestPasswordResetUseCase: any RequestPasswordResetUseCaseProtocol,
        verifyRecoveryOTPUseCase: any VerifyRecoveryOTPUseCaseProtocol,
        updatePasswordUseCase: any UpdatePasswordUseCaseProtocol,
        onComplete: @escaping () -> Void
    ) {
        self.requestPasswordResetUseCase = requestPasswordResetUseCase
        self.verifyRecoveryOTPUseCase = verifyRecoveryOTPUseCase
        self.updatePasswordUseCase = updatePasswordUseCase
        self.onComplete = onComplete
    }

    func sendCode() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error = .emptyEmail
            return
        }
        isLoading = true
        error = nil
        do {
            try await requestPasswordResetUseCase.request(email: email)
            // Success regardless of account existence (server-side
            // enumeration protection) — always advance.
            step = .enterCode
            startCooldown()
        } catch {
            self.error = Self.describeRequest(error)
        }
        isLoading = false
    }

    func verifyCode() async {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            error = .emptyCode
            return
        }
        isLoading = true
        error = nil
        do {
            try await verifyRecoveryOTPUseCase.verify(email: email, code: trimmedCode)
            step = .newPassword
        } catch {
            self.error = Self.describeVerify(error)
        }
        isLoading = false
    }

    func submitNewPassword() async {
        isLoading = true
        error = nil
        do {
            try await updatePasswordUseCase.update(newPassword: newPassword)
            // Stay on the .done success screen — `finish()` (the
            // 開始使用 button) completes the flow.
            step = .done
        } catch {
            self.error = Self.describeUpdate(error)
        }
        isLoading = false
    }

    /// The success screen's 開始使用 button — dismisses the flow into
    /// the (already signed-in) app.
    func finish() {
        onComplete()
    }

    /// Same request as `sendCode` but stays on the code step — used by
    /// the "resend" affordance. SDK 2.5.1 has no recovery resend type,
    /// so this is a fresh `/recover` call.
    func resendCode() async {
        guard resendSecondsRemaining == 0 else { return }
        isLoading = true
        do {
            try await requestPasswordResetUseCase.request(email: email)
            error = nil
            startCooldown()
        } catch {
            self.error = Self.describeRequest(error)
        }
        isLoading = false
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

    static func describeRequest(_ error: RequestPasswordResetError) -> ResetError {
        switch error {
        case .emptyEmail: return .emptyEmail
        case .rateLimited: return .rateLimited
        case .network: return .network
        case .generic: return .generic
        }
    }

    static func describeVerify(_ error: VerifyRecoveryOTPError) -> ResetError {
        switch error {
        case .invalidCodeFormat: return .invalidCodeFormat
        case .invalidOrExpiredCode: return .invalidOrExpiredCode
        case .rateLimited: return .rateLimited
        case .network: return .network
        case .generic: return .generic
        }
    }

    static func describeUpdate(_ error: UpdatePasswordError) -> ResetError {
        switch error {
        case .shortPassword: return .shortPassword
        case .samePassword: return .samePassword
        case .weakPassword: return .weakPassword
        case .network: return .network
        case .generic: return .generic
        }
    }
}

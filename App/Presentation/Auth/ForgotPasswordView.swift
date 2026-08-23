import SwiftUI

/// Three-step in-app password reset, presented as a fullScreenCover
/// owned by RootView (NOT LoginView): step 2's `verifyOTP(.recovery)`
/// signs the user in and flips RootView's auth state underneath — the
/// cover must survive that flip so step 3 can set the new password.
/// Cancelling after step 2 leaves the user signed in (documented
/// behavior — they proved mailbox ownership).
struct ForgotPasswordView: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @State private var viewModel: ForgotPasswordViewModel
    private let onCancel: () -> Void

    init(viewModel: ForgotPasswordViewModel, onCancel: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if viewModel.step == .done {
                successSection

                startButton
            } else {
                headerSection

                stepFields

                if let error = viewModel.error {
                    Text(errorMessage(for: error))
                        .font(.caption)
                        .foregroundStyle(theme.error)
                        .multilineTextAlignment(.center)
                }

                actionButton

                if viewModel.step == .enterCode {
                    resendButton
                }

                cancelButton
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(theme.bgPrimary)
        // Step swaps replace the fields silently — narrate each step's
        // instruction (or the success title on .done) for VoiceOver.
        .onChange(of: viewModel.step) { _, step in
            let key: String.LocalizationValue = switch step {
            case .enterEmail: "resetEmailInstruction"
            case .enterCode: "resetCodeInstruction"
            case .newPassword: "resetNewPasswordInstruction"
            case .done: "resetSuccessTitle"
            }
            AccessibilityNotification.Announcement(
                String(localized: key, bundle: .forLocale(locale))
            ).post()
        }
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "key.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.system)
                .accessibilityHidden(true)
            Text("resetTitle")
                .font(.title.bold())
                .foregroundStyle(theme.textPrimary)
            Text(instructionKey)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var stepFields: some View {
        switch viewModel.step {
        case .enterEmail:
            TextField("loginEmailPlaceholder", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        case .enterCode:
            TextField("verificationCodePlaceholder", text: $viewModel.code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .font(.title2.monospaced())
                .multilineTextAlignment(.center)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityLabel(Text("verificationCodePlaceholder"))
        case .newPassword, .done:
            SecureField("resetNewPasswordPlaceholder", text: $viewModel.newPassword)
                .textContentType(.newPassword)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var actionButton: some View {
        Button {
            Task {
                switch viewModel.step {
                case .enterEmail: await viewModel.sendCode()
                case .enterCode: await viewModel.verifyCode()
                case .newPassword: await viewModel.submitNewPassword()
                case .done: break
                }
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .accessibilityLabel(Text("a11yLoading"))
            } else {
                Text(actionButtonKey)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
        .background(theme.buttonBgPrimary)
        .foregroundStyle(theme.buttonTextPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .disabled(viewModel.isLoading)
    }

    private var resendButton: some View {
        Button {
            Task { await viewModel.resendCode() }
        } label: {
            Text(resendKey)
                .font(.subheadline)
                .foregroundStyle(
                    viewModel.resendSecondsRemaining > 0
                        ? theme.textSecondary
                        : theme.system
                )
        }
        .disabled(viewModel.resendSecondsRemaining > 0)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text("resetButtonCancel")
                .font(.subheadline)
                .foregroundStyle(theme.system)
        }
    }

    private var successSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(theme.system)
                .accessibilityHidden(true)
            Text("resetSuccessTitle")
                .font(.title.bold())
                .foregroundStyle(theme.textPrimary)
            Text("resetSuccessMessage")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    private var startButton: some View {
        Button {
            viewModel.finish()
        } label: {
            Text("resetButtonStart")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .background(theme.buttonBgPrimary)
        .foregroundStyle(theme.buttonTextPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Localization keys

    private var instructionKey: LocalizedStringKey {
        switch viewModel.step {
        case .enterEmail: "resetEmailInstruction"
        case .enterCode: "resetCodeInstruction"
        case .newPassword, .done: "resetNewPasswordInstruction"
        }
    }

    private var actionButtonKey: LocalizedStringKey {
        switch viewModel.step {
        case .enterEmail: "resetButtonSendCode"
        case .enterCode: "resetButtonVerify"
        case .newPassword, .done: "resetButtonUpdatePassword"
        }
    }

    private var resendKey: LocalizedStringKey {
        viewModel.resendSecondsRemaining > 0
            ? "resetResendCooldown \(viewModel.resendSecondsRemaining)"
            : "resetButtonResend"
    }

    private func errorMessage(
        for error: ForgotPasswordViewModel.ResetError
    ) -> LocalizedStringKey {
        switch error {
        case .emptyEmail: "resetErrorEmptyEmail"
        case .emptyCode: "resetErrorEmptyCode"
        case .invalidCodeFormat: "resetErrorInvalidCodeFormat"
        case .invalidOrExpiredCode: "resetErrorInvalidOrExpiredCode"
        case .shortPassword: "resetErrorShortPassword"
        case .samePassword: "resetErrorSamePassword"
        case .weakPassword: "resetErrorWeakPassword"
        case .rateLimited: "resetErrorRateLimited"
        case .network: "loginErrorNetwork"
        case .generic: "loginErrorGeneric"
        }
    }
}

#Preview {
    ForgotPasswordView(
        viewModel: ForgotPasswordViewModel(
            requestPasswordResetUseCase: AppDependencies.live.requestPasswordResetUseCase,
            verifyRecoveryOTPUseCase: AppDependencies.live.verifyRecoveryOTPUseCase,
            updatePasswordUseCase: AppDependencies.live.updatePasswordUseCase,
            onComplete: {}
        ),
        onCancel: {}
    )
}

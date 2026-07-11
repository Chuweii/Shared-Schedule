import SwiftUI

/// OTP entry screen shown after sign-up (or from the sign-in
/// "email not confirmed" path). On successful verification the SDK
/// emits `.signedIn` and RootView swaps to ContentView — this view
/// never dismisses itself on success.
struct EmailVerificationView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel: EmailVerificationViewModel
    private let onBack: () -> Void

    init(viewModel: EmailVerificationViewModel, onBack: @escaping () -> Void) {
        self._viewModel = State(initialValue: viewModel)
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            headerSection

            codeField

            if let error = viewModel.error {
                Text(errorMessage(for: error))
                    .font(.caption)
                    .foregroundStyle(theme.error)
                    .multilineTextAlignment(.center)
            }

            verifyButton

            resendButton

            backButton

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(theme.bgPrimary)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 48))
                .foregroundStyle(theme.system)
            Text("verificationTitle")
                .font(.title.bold())
                .foregroundStyle(theme.textPrimary)
            Text("verificationSubtitle")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Text(verbatim: viewModel.email)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var codeField: some View {
        TextField("verificationCodePlaceholder", text: $viewModel.code)
            .textContentType(.oneTimeCode)
            .keyboardType(.numberPad)
            .font(.title2.monospaced())
            .multilineTextAlignment(.center)
            .padding()
            .background(theme.textFieldBgPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var verifyButton: some View {
        Button {
            Task { await viewModel.verify() }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text("verificationButtonVerify")
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
            Task { await viewModel.resend() }
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

    private var backButton: some View {
        Button(action: onBack) {
            Text("verificationBackToLogin")
                .font(.subheadline)
                .foregroundStyle(theme.system)
        }
    }

    // MARK: - Localization keys

    private var resendKey: LocalizedStringKey {
        viewModel.resendSecondsRemaining > 0
            ? "verificationResendCooldown \(viewModel.resendSecondsRemaining)"
            : "verificationButtonResend"
    }

    private func errorMessage(
        for error: EmailVerificationViewModel.VerificationError
    ) -> LocalizedStringKey {
        switch error {
        case .emptyCode: "verificationErrorEmptyCode"
        case .invalidCodeFormat: "verificationErrorInvalidCodeFormat"
        case .invalidOrExpiredCode: "verificationErrorInvalidOrExpiredCode"
        case .rateLimited: "verificationErrorRateLimited"
        case .network: "loginErrorNetwork"
        case .generic: "loginErrorGeneric"
        }
    }
}

#Preview {
    EmailVerificationView(
        viewModel: EmailVerificationViewModel(
            email: "student@example.com",
            displayName: "小明",
            verifyEmailOTPUseCase: AppDependencies.live.verifyEmailOTPUseCase,
            resendVerificationCodeUseCase: AppDependencies.live.resendVerificationCodeUseCase,
            currentUserProvider: AppDependencies.live.currentUserProvider
        ),
        onBack: {}
    )
}

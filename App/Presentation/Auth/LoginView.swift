import SwiftUI

struct LoginView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel: LoginViewModel
    @State private var isSignUpMode = false

    init(completeSignUpUseCase: (any CompleteSignUpUseCaseProtocol)? = nil) {
        self._viewModel = State(initialValue: LoginViewModel(
            completeSignUpUseCase: completeSignUpUseCase
        ))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            headerSection

            inputFields

            if let error = viewModel.error {
                Text(errorMessage(for: error))
                    .font(.caption)
                    .foregroundStyle(theme.error)
                    .multilineTextAlignment(.center)
            }

            actionButton

            toggleModeButton

            Spacer()
        }
        .padding(.horizontal, 32)
        .background(theme.bgPrimary)
    }

    // MARK: - Subviews

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(theme.system)
            Text("Shared Schedule")
                .font(.title.bold())
                .foregroundStyle(theme.textPrimary)
            Text(subtitleKey)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var inputFields: some View {
        VStack(spacing: 12) {
            TextField("loginEmailPlaceholder", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            SecureField("loginPasswordPlaceholder", text: $viewModel.password)
                .textContentType(isSignUpMode ? .newPassword : .password)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            if isSignUpMode {
                TextField("signUpDisplayNamePlaceholder", text: $viewModel.displayName)
                    .textContentType(.name)
                    .padding()
                    .background(theme.textFieldBgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var actionButton: some View {
        Button {
            Task {
                if isSignUpMode {
                    await viewModel.signUp()
                } else {
                    await viewModel.signIn()
                }
            }
        } label: {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
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

    private var toggleModeButton: some View {
        Button {
            isSignUpMode.toggle()
            viewModel.error = nil
        } label: {
            Text(toggleModeKey)
                .font(.subheadline)
                .foregroundStyle(theme.system)
        }
    }

    // MARK: - Localization keys
    // Ternaries stay typed as LocalizedStringKey (a bare literal ternary
    // would infer String and render verbatim, bypassing the catalog).

    private var subtitleKey: LocalizedStringKey {
        isSignUpMode ? "loginSubtitleSignUp" : "loginSubtitleSignIn"
    }

    private var actionButtonKey: LocalizedStringKey {
        isSignUpMode ? "loginButtonSignUp" : "loginButtonSignIn"
    }

    private var toggleModeKey: LocalizedStringKey {
        isSignUpMode ? "loginSwitchToSignIn" : "loginSwitchToSignUp"
    }

    private func errorMessage(for error: LoginViewModel.LoginError) -> LocalizedStringKey {
        switch error {
        case .emptyEmail: "loginErrorEmptyEmail"
        case .shortPassword: "loginErrorShortPassword"
        case .emptyDisplayName: "signUpErrorEmptyDisplayName"
        case .displayNameTooLong: "signUpErrorDisplayNameTooLong"
        case .invalidCredentials: "loginErrorInvalidCredentials"
        case .userExists: "loginErrorUserExists"
        case .weakPassword: "loginErrorWeakPassword"
        case .partialFailure: "signUpErrorPartialFailure"
        case .network: "loginErrorNetwork"
        case .generic: "loginErrorGeneric"
        }
    }
}

#Preview {
    LoginView()
}

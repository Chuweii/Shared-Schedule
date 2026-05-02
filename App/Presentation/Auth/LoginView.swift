import SwiftUI

struct LoginView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel = LoginViewModel()
    @State private var isSignUpMode = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            headerSection

            inputFields

            if let error = viewModel.errorMessage {
                Text(error)
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
            Text(isSignUpMode
                 ? String(localized: "loginSubtitleSignUp")
                 : String(localized: "loginSubtitleSignIn"))
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var inputFields: some View {
        VStack(spacing: 12) {
            TextField(String(localized: "loginEmailPlaceholder"), text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            SecureField(String(localized: "loginPasswordPlaceholder"), text: $viewModel.password)
                .textContentType(isSignUpMode ? .newPassword : .password)
                .padding()
                .background(theme.textFieldBgPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
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
                Text(isSignUpMode
                     ? String(localized: "loginButtonSignUp")
                     : String(localized: "loginButtonSignIn"))
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
            viewModel.errorMessage = nil
        } label: {
            Text(isSignUpMode
                 ? String(localized: "loginSwitchToSignIn")
                 : String(localized: "loginSwitchToSignUp"))
                .font(.subheadline)
                .foregroundStyle(theme.system)
        }
    }
}

#Preview {
    LoginView()
}

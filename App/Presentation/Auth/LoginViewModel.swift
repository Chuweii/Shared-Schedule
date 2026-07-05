import Auth
import Foundation

@Observable
final class LoginViewModel {
    /// Presentation-level error cases. The View maps each case to a
    /// `LocalizedStringKey` so messages follow the in-app language
    /// override (`String(localized:)` resolved here would not).
    enum LoginError: Equatable {
        case emptyEmail
        case shortPassword
        case emptyDisplayName
        case displayNameTooLong
        case invalidCredentials
        case userExists
        case weakPassword
        case partialFailure
        case network
        case generic
    }

    var email = ""
    var password = ""
    var displayName = ""
    var isLoading = false
    var error: LoginError?

    private let authClient: AuthClient
    private let completeSignUpUseCase: (any CompleteSignUpUseCaseProtocol)?

    init(
        authClient: AuthClient = SupabaseClientProvider.auth,
        completeSignUpUseCase: (any CompleteSignUpUseCaseProtocol)? = nil
    ) {
        self.authClient = authClient
        self.completeSignUpUseCase = completeSignUpUseCase
    }

    func signIn() async {
        guard validateSignInInput() else { return }
        isLoading = true
        error = nil
        do {
            try await authClient.signIn(email: email, password: password)
        } catch {
            self.error = Self.describe(error)
        }
        isLoading = false
    }

    func signUp() async {
        guard let completeSignUpUseCase else {
            error = .generic
            return
        }
        // Pre-flight on displayName specifically (the other two are
        // covered by the usecase + signIn path's validateSignInInput
        // for parity with sign-in error UX).
        guard validateSignUpInput() else { return }
        isLoading = true
        error = nil
        do {
            try await completeSignUpUseCase.completeSignUp(
                email: email,
                password: password,
                displayName: displayName
            )
        } catch {
            self.error = Self.describeSignUp(error)
        }
        isLoading = false
    }

    static func describe(_ error: Error) -> LoginError {
        if error is URLError {
            return .network
        }
        if case let AuthError.api(apiError) = error {
            if apiError.weakPassword != nil {
                return .weakPassword
            }
            switch apiError.code {
            case 400: return .invalidCredentials
            case 422: return .userExists
            default: break
            }
        }
        return .generic
    }

    static func describeSignUp(_ error: CompleteSignUpError) -> LoginError {
        switch error {
        case .invalidEmail: return .emptyEmail
        case .invalidPassword: return .shortPassword
        // Empty case is already caught client-side via validateSignUpInput,
        // so the server-side .invalidDisplayName is overwhelmingly the
        // "too long" branch — surface that.
        case .invalidDisplayName: return .displayNameTooLong
        case .userAlreadyExists: return .userExists
        case .weakPassword: return .weakPassword
        case .partialFailure: return .partialFailure
        case .network: return .network
        case .generic: return .generic
        }
    }

    private func validateSignInInput() -> Bool {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = .emptyEmail
            return false
        }
        if password.count < 6 {
            error = .shortPassword
            return false
        }
        return true
    }

    private func validateSignUpInput() -> Bool {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            error = .emptyEmail
            return false
        }
        if password.count < 6 {
            error = .shortPassword
            return false
        }
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDisplayName.isEmpty {
            error = .emptyDisplayName
            return false
        }
        if trimmedDisplayName.count > 50 {
            error = .displayNameTooLong
            return false
        }
        return true
    }
}

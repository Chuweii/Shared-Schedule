import Auth
import Foundation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var displayName = ""
    var isLoading = false
    var errorMessage: String?

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
        errorMessage = nil
        do {
            try await authClient.signIn(email: email, password: password)
        } catch {
            errorMessage = Self.describe(error)
        }
        isLoading = false
    }

    func signUp() async {
        guard let completeSignUpUseCase else {
            errorMessage = String(localized: "loginErrorGeneric")
            return
        }
        // Pre-flight on displayName specifically (the other two are
        // covered by the usecase + signIn path's validateSignInInput
        // for parity with sign-in error UX).
        guard validateSignUpInput() else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await completeSignUpUseCase.completeSignUp(
                email: email,
                password: password,
                displayName: displayName
            )
        } catch {
            errorMessage = Self.describeSignUp(error)
        }
        isLoading = false
    }

    static func describe(_ error: Error) -> String {
        if error is URLError {
            return String(localized: "loginErrorNetwork")
        }
        if case let AuthError.api(apiError) = error {
            if apiError.weakPassword != nil {
                return String(localized: "loginErrorWeakPassword")
            }
            switch apiError.code {
            case 400: return String(localized: "loginErrorInvalidCredentials")
            case 422: return String(localized: "loginErrorUserExists")
            default: break
            }
        }
        return String(localized: "loginErrorGeneric")
    }

    static func describeSignUp(_ error: CompleteSignUpError) -> String {
        switch error {
        case .invalidEmail: return String(localized: "loginErrorEmptyEmail")
        case .invalidPassword: return String(localized: "loginErrorShortPassword")
        // Empty case is already caught client-side via validateSignUpInput,
        // so the server-side .invalidDisplayName is overwhelmingly the
        // "too long" branch — surface that.
        case .invalidDisplayName: return String(localized: "signUpErrorDisplayNameTooLong")
        case .userAlreadyExists: return String(localized: "loginErrorUserExists")
        case .weakPassword: return String(localized: "loginErrorWeakPassword")
        case .partialFailure: return String(localized: "signUpErrorPartialFailure")
        case .network: return String(localized: "loginErrorNetwork")
        case .generic: return String(localized: "loginErrorGeneric")
        }
    }

    private func validateSignInInput() -> Bool {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = String(localized: "loginErrorEmptyEmail")
            return false
        }
        if password.count < 6 {
            errorMessage = String(localized: "loginErrorShortPassword")
            return false
        }
        return true
    }

    private func validateSignUpInput() -> Bool {
        if email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = String(localized: "loginErrorEmptyEmail")
            return false
        }
        if password.count < 6 {
            errorMessage = String(localized: "loginErrorShortPassword")
            return false
        }
        let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedDisplayName.isEmpty {
            errorMessage = String(localized: "signUpErrorEmptyDisplayName")
            return false
        }
        if trimmedDisplayName.count > 50 {
            errorMessage = String(localized: "signUpErrorDisplayNameTooLong")
            return false
        }
        return true
    }
}

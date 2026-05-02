import Auth
import Foundation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?

    private let authClient: AuthClient

    init(authClient: AuthClient = SupabaseClientProvider.auth) {
        self.authClient = authClient
    }

    func signIn() async {
        guard validateInput() else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authClient.signIn(email: email, password: password)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    func signUp() async {
        guard validateInput() else { return }
        isLoading = true
        errorMessage = nil
        do {
            try await authClient.signUp(email: email, password: password)
        } catch {
            errorMessage = describe(error)
        }
        isLoading = false
    }

    private func describe(_ error: Error) -> String {
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

    private func validateInput() -> Bool {
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
}

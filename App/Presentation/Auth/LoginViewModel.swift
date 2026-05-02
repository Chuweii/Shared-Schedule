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
            errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription
        }
        isLoading = false
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

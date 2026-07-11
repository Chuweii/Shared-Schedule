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
        case emailNotConfirmed
        case userExists
        case weakPassword
        case network
        case generic
    }

    /// Set when the flow should move to the OTP verification screen.
    /// `displayName` is non-nil right after sign-up (profile is created
    /// post-verification) and nil on the deferred-verification path
    /// (re-entry from the sign-in `.emailNotConfirmed` error).
    struct PendingVerification: Equatable, Identifiable {
        let email: String
        let displayName: String?

        var id: String { email }
    }

    var email = ""
    var password = ""
    var displayName = ""
    var isLoading = false
    var error: LoginError?
    var pendingVerification: PendingVerification?

    private let signInUseCase: (any SignInUseCaseProtocol)?
    private let completeSignUpUseCase: (any CompleteSignUpUseCaseProtocol)?
    private let resendVerificationCodeUseCase: (any ResendVerificationCodeUseCaseProtocol)?

    init(
        signInUseCase: (any SignInUseCaseProtocol)? = nil,
        completeSignUpUseCase: (any CompleteSignUpUseCaseProtocol)? = nil,
        resendVerificationCodeUseCase: (any ResendVerificationCodeUseCaseProtocol)? = nil
    ) {
        self.signInUseCase = signInUseCase
        self.completeSignUpUseCase = completeSignUpUseCase
        self.resendVerificationCodeUseCase = resendVerificationCodeUseCase
    }

    func signIn() async {
        guard let signInUseCase else {
            error = .generic
            return
        }
        guard validateSignInInput() else { return }
        isLoading = true
        error = nil
        do {
            try await signInUseCase.signIn(email: email, password: password)
        } catch {
            self.error = Self.describeSignIn(error)
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
            // No session yet (email confirmations enabled) — move to
            // the OTP screen carrying the displayName for the
            // post-verification profile creation.
            pendingVerification = PendingVerification(
                email: trimmedEmail,
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            self.error = Self.describeSignUp(error)
        }
        isLoading = false
    }

    /// Entry from the sign-in `.emailNotConfirmed` error: resend the
    /// code (best-effort — the OTP screen has its own resend button)
    /// and move to verification without a displayName (the profile
    /// will be repaired via Settings if it never got created).
    func proceedToVerification() async {
        guard let resendVerificationCodeUseCase else {
            error = .generic
            return
        }
        isLoading = true
        try? await resendVerificationCodeUseCase.resend(email: email)
        error = nil
        pendingVerification = PendingVerification(email: trimmedEmail, displayName: nil)
        isLoading = false
    }

    private var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func describeSignIn(_ error: SignInError) -> LoginError {
        switch error {
        case .emailNotConfirmed: return .emailNotConfirmed
        case .invalidCredentials: return .invalidCredentials
        case .network: return .network
        case .generic: return .generic
        }
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
        case .network: return .network
        case .generic: return .generic
        }
    }

    private func validateSignInInput() -> Bool {
        if trimmedEmail.isEmpty {
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
        if trimmedEmail.isEmpty {
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

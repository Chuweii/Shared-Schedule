import SwiftUI
import Auth
import OSLog

private let log = Logger(subsystem: "com.Kyoi.Shared-Schedule", category: "Auth")

struct RootView: View {
    @State private var authState: AuthState = .loading
    @State private var isPasswordResetPresented = false
    @State private var pendingVerification: LoginViewModel.PendingVerification?
    @State private var showsSignInSuccess = false
    private let userProfileRepository: SupabaseUserProfileRepository
    private let accountRepository: SupabaseAccountRepository
    private let authSignUpClient: SupabaseAuthSignUpClient
    private let authSessionClient: SupabaseAuthSessionClient
    private let authPasswordResetClient: SupabaseAuthPasswordResetClient
    @State private var userProvider: SupabaseAuthCurrentUserProvider

    init() {
        let repo = SupabaseUserProfileRepository()
        self.userProfileRepository = repo
        self.accountRepository = SupabaseAccountRepository()
        self.authSignUpClient = SupabaseAuthSignUpClient()
        self.authSessionClient = SupabaseAuthSessionClient()
        self.authPasswordResetClient = SupabaseAuthPasswordResetClient()
        self._userProvider = State(
            initialValue: SupabaseAuthCurrentUserProvider(userProfileRepository: repo)
        )
    }

    var body: some View {
        Group {
            switch authState {
            case .loading:
                ProgressView()
            case .authenticated:
                ContentView(
                    dependencies: AppDependencies(
                        repository: SupabaseScheduleRepository(),
                        invitationRepository: SupabaseInvitationRepository(),
                        bookingRepository: SupabaseBookingRepository(),
                        userProfileRepository: userProfileRepository,
                        accountRepository: accountRepository,
                        authSignUpClient: authSignUpClient,
                        currentUserProvider: userProvider
                    ),
                    onSignOut: signOut,
                    onAccountDeleted: handleAccountDeleted
                )
            case .unauthenticated:
                LoginView(
                    signInUseCase: SignInUseCase(authSessionClient: authSessionClient),
                    completeSignUpUseCase: CompleteSignUpUseCase(
                        authSignUpClient: authSignUpClient
                    ),
                    resendVerificationCodeUseCase: ResendVerificationCodeUseCase(
                        authSessionClient: authSessionClient
                    ),
                    onForgotPassword: { isPasswordResetPresented = true },
                    onVerificationNeeded: { pendingVerification = $0 },
                    onSignInSuccess: { showsSignInSuccess = true }
                )
            }
        }
        .task {
            await observeAuthState()
        }
        // Welcome-back toast over ContentView after an interactive
        // sign-in. The OTP flows and session restore never trigger
        // this (they signal via their own paths).
        .toast(
            isPresented: $showsSignInSuccess,
            message: "loginSuccessWelcomeBack",
            duration: .seconds(1.5)
        )
        // Both covers attach to the outer Group, NOT LoginView: OTP
        // verification and step 2 of the reset flow fire .signedIn and
        // flip authState — the flows must survive that flip so their
        // success screens can show before dismissing into the app.
        // (They are never presented simultaneously.)
        .fullScreenCover(item: $pendingVerification) { pending in
            EmailVerificationView(
                viewModel: EmailVerificationViewModel(
                    email: pending.email,
                    displayName: pending.displayName,
                    verifyEmailOTPUseCase: VerifyEmailOTPUseCase(
                        authSessionClient: authSessionClient,
                        userProfileRepository: userProfileRepository
                    ),
                    resendVerificationCodeUseCase: ResendVerificationCodeUseCase(
                        authSessionClient: authSessionClient
                    ),
                    currentUserProvider: userProvider
                ),
                onDismiss: { pendingVerification = nil }
            )
        }
        .fullScreenCover(isPresented: $isPasswordResetPresented) {
            ForgotPasswordView(
                viewModel: ForgotPasswordViewModel(
                    requestPasswordResetUseCase: RequestPasswordResetUseCase(
                        authPasswordResetClient: authPasswordResetClient
                    ),
                    verifyRecoveryOTPUseCase: VerifyRecoveryOTPUseCase(
                        authPasswordResetClient: authPasswordResetClient
                    ),
                    updatePasswordUseCase: UpdatePasswordUseCase(
                        authPasswordResetClient: authPasswordResetClient
                    ),
                    onComplete: { isPasswordResetPresented = false }
                ),
                onCancel: { isPasswordResetPresented = false }
            )
        }
    }

    private func signOut() async {
        do {
            try await SupabaseClientProvider.auth.signOut()
        } catch {
            log.error("signOut failed: \(error.localizedDescription, privacy: .public)")
        }
        // Defensive: SDK only ignores 401/404 errors — a 403 (e.g. session
        // already removed server-side after a `db reset`) leaves the keychain
        // populated, so manually clear it and the in-memory state.
        do {
            try AuthClient.Configuration.defaultLocalStorage.remove(key: "supabase.session")
        } catch {
            log.error("local session removal failed: \(error.localizedDescription, privacy: .public)")
        }
        userProvider.clear()
        setAuthState(.unauthenticated)
    }

    /// After a successful account deletion the server session is already
    /// invalid (the auth.users row is gone). Reuse the sign-out teardown:
    /// the network sign-out 401s harmlessly and the keychain + in-memory
    /// state are cleared, routing back to the login gate.
    private func handleAccountDeleted() async {
        log.info("account deleted; tearing down session")
        await signOut()
    }

    /// Cross-fades the login-gate branch swap instead of hard-cutting.
    private func setAuthState(_ newState: AuthState) {
        withAnimation(.easeInOut(duration: 0.3)) {
            authState = newState
        }
    }

    private func observeAuthState() async {
        // Check initial session
        do {
            let session = try await SupabaseClientProvider.auth.session
            await userProvider.update(from: session.user)
            setAuthState(.authenticated)
        } catch {
            log.info("no active session: \(error.localizedDescription, privacy: .public)")
            setAuthState(.unauthenticated)
        }

        // Listen for ongoing auth state changes
        for await (event, session) in await SupabaseClientProvider.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let user = session?.user {
                    await userProvider.update(from: user)
                }
                setAuthState(.authenticated)
            case .signedOut:
                userProvider.clear()
                setAuthState(.unauthenticated)
            default:
                break
            }
        }
    }
}

private enum AuthState {
    case loading
    case authenticated
    case unauthenticated
}

import SwiftUI
import Auth
import OSLog

private let log = Logger(subsystem: "com.Kyoi.Shared-Schedule", category: "Auth")

struct RootView: View {
    @State private var authState: AuthState = .loading
    private let userProfileRepository: SupabaseUserProfileRepository
    private let accountRepository: SupabaseAccountRepository
    private let authSignUpClient: SupabaseAuthSignUpClient
    private let authSessionClient: SupabaseAuthSessionClient
    @State private var userProvider: SupabaseAuthCurrentUserProvider

    init() {
        let repo = SupabaseUserProfileRepository()
        self.userProfileRepository = repo
        self.accountRepository = SupabaseAccountRepository()
        self.authSignUpClient = SupabaseAuthSignUpClient()
        self.authSessionClient = SupabaseAuthSessionClient()
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
                    verifyEmailOTPUseCase: VerifyEmailOTPUseCase(
                        authSessionClient: authSessionClient,
                        userProfileRepository: userProfileRepository
                    ),
                    resendVerificationCodeUseCase: ResendVerificationCodeUseCase(
                        authSessionClient: authSessionClient
                    ),
                    currentUserProvider: userProvider
                )
            }
        }
        .task {
            await observeAuthState()
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
        authState = .unauthenticated
    }

    /// After a successful account deletion the server session is already
    /// invalid (the auth.users row is gone). Reuse the sign-out teardown:
    /// the network sign-out 401s harmlessly and the keychain + in-memory
    /// state are cleared, routing back to the login gate.
    private func handleAccountDeleted() async {
        log.info("account deleted; tearing down session")
        await signOut()
    }

    private func observeAuthState() async {
        // Check initial session
        do {
            let session = try await SupabaseClientProvider.auth.session
            await userProvider.update(from: session.user)
            authState = .authenticated
        } catch {
            log.info("no active session: \(error.localizedDescription, privacy: .public)")
            authState = .unauthenticated
        }

        // Listen for ongoing auth state changes
        for await (event, session) in await SupabaseClientProvider.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let user = session?.user {
                    await userProvider.update(from: user)
                }
                authState = .authenticated
            case .signedOut:
                userProvider.clear()
                authState = .unauthenticated
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

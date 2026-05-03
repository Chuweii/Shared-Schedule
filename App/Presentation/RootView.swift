import SwiftUI
import Auth
import OSLog

private let log = Logger(subsystem: "com.Kyoi.Shared-Schedule", category: "Auth")

struct RootView: View {
    @State private var authState: AuthState = .loading
    @State private var userProvider = SupabaseAuthCurrentUserProvider()

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
                        currentUserProvider: userProvider
                    ),
                    onSignOut: signOut
                )
            case .unauthenticated:
                LoginView()
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

    private func observeAuthState() async {
        // Check initial session
        do {
            let session = try await SupabaseClientProvider.auth.session
            userProvider.update(from: session.user)
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
                    userProvider.update(from: user)
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

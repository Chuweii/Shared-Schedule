import SwiftUI
import Auth

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
                        currentUserProvider: userProvider
                    )
                )
            case .unauthenticated:
                LoginView()
            }
        }
        .task {
            await observeAuthState()
        }
    }

    private func observeAuthState() async {
        // Check initial session
        if let session = try? await SupabaseClientProvider.auth.session {
            userProvider.update(from: session.user)
            authState = .authenticated
        } else {
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

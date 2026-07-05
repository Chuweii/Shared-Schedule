import Foundation

/// Used by `AppDependencies.live` for SwiftUI previews. Production code
/// path (RootView) wires `SupabaseAccountRepository` directly.
nonisolated final class InMemoryAccountRepository: AccountRepositoryProtocol, @unchecked Sendable {
    func deleteAccount() async throws(DeleteAccountError) {
        // No-op success for previews.
    }
}

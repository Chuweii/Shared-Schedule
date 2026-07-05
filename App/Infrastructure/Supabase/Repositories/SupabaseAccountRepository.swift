import PostgREST
import Auth
import Foundation

final class SupabaseAccountRepository: AccountRepositoryProtocol, @unchecked Sendable {

    private func db() async throws -> PostgrestClient {
        let session = try await SupabaseClientProvider.auth.session
        return SupabaseClientProvider.database(accessToken: session.accessToken)
    }

    func deleteAccount() async throws(DeleteAccountError) {
        do {
            try await db()
                .rpc("delete_account")
                .execute()
        } catch is URLError {
            throw .network
        } catch let pg as PostgrestError {
            if pg.localizedDescription.contains("AUTH_REQUIRED") {
                throw .notAuthenticated
            }
            throw .persistenceFailure
        } catch {
            throw .persistenceFailure
        }
    }
}

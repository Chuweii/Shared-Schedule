import Testing
import Foundation
import Auth
@testable import Shared_Schedule

extension Tag {
    @Tag static var integration: Self
}

enum IntegrationTestSupport {

    static let userAEmail = "test-teacher@example.com"
    static let userBEmail = "test-teacher-b@example.com"
    static let testPassword = "password123"

    static let userAID = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    static let userBID = UUID(uuidString: "b2c3d4e5-f6a7-8901-bcde-f23456789012")!

    private static let healthURL = URL(string: "http://127.0.0.1:54321/rest/v1/")!
    private static let publishableKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

    static func requireLocalStack() async throws {
        var request = URLRequest(url: healthURL)
        request.timeoutInterval = 2
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            Issue.record(
                "Local Supabase stack not reachable at 127.0.0.1:54321 — run `supabase start` then `supabase db reset` and re-run."
            )
            throw error
        }
    }

    @discardableResult
    static func signIn(email: String) async throws -> UUID {
        let auth = SupabaseClientProvider.auth
        try? await auth.signOut()
        let session = try await auth.signIn(email: email, password: testPassword)
        return session.user.id
    }

    static func signInReturningAuthUser(email: String) async throws -> Auth.User {
        let auth = SupabaseClientProvider.auth
        try? await auth.signOut()
        let session = try await auth.signIn(email: email, password: testPassword)
        return session.user
    }

    static func signOut() async {
        try? await SupabaseClientProvider.auth.signOut()
    }
}

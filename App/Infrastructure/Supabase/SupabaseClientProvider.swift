import Auth
import PostgREST
import Foundation

enum SupabaseClientProvider {

    // MARK: - Local dev configuration (hardcoded for Phase 2)

    private static let baseURL = URL(string: "http://127.0.0.1:54321")!
    private static let anonKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

    // MARK: - Auth client

    static let auth: AuthClient = {
        AuthClient(
            configuration: AuthClient.Configuration(
                url: baseURL.appendingPathComponent("auth/v1"),
                headers: ["apikey": anonKey],
                flowType: .implicit,
                localStorage: AuthClient.Configuration.defaultLocalStorage
            )
        )
    }()

    // MARK: - PostgREST client (with current auth token)

    static func database(accessToken: String? = nil) -> PostgrestClient {
        var headers: [String: String] = ["apikey": anonKey]
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return PostgrestClient(
            url: baseURL.appendingPathComponent("rest/v1"),
            schema: "public",
            headers: headers
        )
    }
}

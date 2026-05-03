import Auth
import PostgREST
import Foundation

enum SupabaseClientProvider {

    // MARK: - Configuration (loaded from xcconfig → Info.plist)

    private static let baseURL: URL = {
        let raw = readRequiredString("SUPABASE_URL")
        guard let url = URL(string: raw) else {
            fatalError("SUPABASE_URL is not a valid URL: \(raw)")
        }
        return url
    }()

    private static let anonKey: String = readRequiredString("SUPABASE_ANON_KEY")

    private static func readRequiredString(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty
        else {
            fatalError(
                "\(key) missing from Info.plist. Check Config/<config>.xcconfig is wired into the build configuration. See docs/backend.md §3."
            )
        }
        if value.contains("PLACEHOLDER") {
            fatalError(
                "\(key) is still a PLACEHOLDER. Fill in real values in Config/<config>.xcconfig before running this build configuration."
            )
        }
        return value
    }

    // MARK: - Auth client

    static let auth: AuthClient = {
        AuthClient(
            configuration: AuthClient.Configuration(
                url: baseURL.appendingPathComponent("auth/v1"),
                headers: ["apikey": anonKey],
                flowType: .implicit,
                localStorage: AuthClient.Configuration.defaultLocalStorage,
                logger: nil
            )
        )
    }()

    // MARK: - PostgREST client (with current auth token)

    private static let snakeCaseDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let snakeCaseEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static func database(accessToken: String? = nil) -> PostgrestClient {
        var headers: [String: String] = ["apikey": anonKey]
        if let token = accessToken {
            headers["Authorization"] = "Bearer \(token)"
        }
        return PostgrestClient(
            url: baseURL.appendingPathComponent("rest/v1"),
            schema: "public",
            headers: headers,
            logger: nil,
            encoder: snakeCaseEncoder,
            decoder: snakeCaseDecoder
        )
    }
}

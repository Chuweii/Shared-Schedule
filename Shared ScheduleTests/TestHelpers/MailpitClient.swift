import Foundation

/// Minimal client for the local Supabase stack's Mailpit test inbox
/// (web UI at http://127.0.0.1:54324 — the CLI's `[inbucket]` config
/// section kept the old name, but the server is Mailpit). Used by
/// integration tests to pull the 6-digit OTP out of confirmation /
/// recovery emails.
enum MailpitClient {

    private static let baseURL = URL(string: "http://127.0.0.1:54324/api/v1")!

    struct MailpitError: Error {
        let message: String
    }

    /// Polls the mailbox until at least one message addressed to
    /// `email` exists, then extracts the first 6-digit run from the
    /// newest message's text body.
    static func waitForLatestOTP(
        to email: String,
        timeout: Duration = .seconds(10)
    ) async throws -> String {
        let messageID = try await waitForMessageIDs(to: email, atLeast: 1, timeout: timeout)[0]
        let text = try await messageText(id: messageID)
        guard let match = text.firstMatch(of: /[0-9]{6}/) else {
            throw MailpitError(message: "No 6-digit OTP found in message \(messageID): \(text.prefix(200))")
        }
        return String(match.output)
    }

    /// Number of messages currently addressed to `email`.
    static func messageCount(to email: String) async throws -> Int {
        try await searchMessageIDs(to: email).count
    }

    /// Polls until the mailbox holds at least `count` messages —
    /// newest first, per Mailpit's search ordering.
    @discardableResult
    static func waitForMessageIDs(
        to email: String,
        atLeast count: Int,
        timeout: Duration = .seconds(10)
    ) async throws -> [String] {
        let deadline = ContinuousClock.now + timeout
        while true {
            let ids = try await searchMessageIDs(to: email)
            if ids.count >= count { return ids }
            guard ContinuousClock.now < deadline else {
                throw MailpitError(
                    message: "Timed out waiting for \(count) message(s) to \(email); found \(ids.count). Is `supabase start` running with confirmations enabled?"
                )
            }
            try await Task.sleep(for: .milliseconds(500))
        }
    }

    // MARK: - Raw API

    private struct SearchResponse: Decodable {
        struct Message: Decodable {
            let id: String

            private enum CodingKeys: String, CodingKey {
                case id = "ID"
            }
        }

        let messages: [Message]
    }

    private struct MessageResponse: Decodable {
        let text: String

        private enum CodingKeys: String, CodingKey {
            case text = "Text"
        }
    }

    private static func searchMessageIDs(to email: String) async throws -> [String] {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("search"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "query", value: "to:\"\(email)\"")]
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(SearchResponse.self, from: data).messages.map(\.id)
    }

    private static func messageText(id: String) async throws -> String {
        let url = baseURL.appendingPathComponent("message/\(id)")
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(MessageResponse.self, from: data).text
    }
}

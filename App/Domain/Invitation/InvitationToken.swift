import Foundation

/// 8-char Crockford Base32 (alphabet `0-9A-Z` minus I L O U) — picked to
/// look unambiguous when handed off in chat or read aloud. 32^8 ≈ 1.1T,
/// so the DB UNIQUE constraint catches collisions but they're vanishingly
/// rare in practice.
nonisolated struct InvitationToken: Hashable, Sendable {

    static let length = 8

    /// Crockford alphabet without I L O U.
    static let alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

    let rawValue: String

    init(_ rawValue: String) throws(InvitationTokenError) {
        guard rawValue.count == Self.length else {
            throw .invalidLength
        }
        let allowed = Set(Self.alphabet)
        guard rawValue.allSatisfy({ allowed.contains($0) }) else {
            throw .invalidCharacter
        }
        self.rawValue = rawValue
    }

    static func generate() -> InvitationToken {
        let chars = Array(alphabet)
        var rng = SystemRandomNumberGenerator()
        let value = String((0..<length).map { _ in chars.randomElement(using: &rng)! })
        // Safe — we just constructed `value` from the alphabet.
        return try! InvitationToken(value)
    }
}

nonisolated enum InvitationTokenError: Error, Equatable, Sendable {
    case invalidLength
    case invalidCharacter
}

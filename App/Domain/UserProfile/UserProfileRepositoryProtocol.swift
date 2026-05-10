import Foundation

protocol UserProfileRepositoryProtocol: Sendable {
    /// Atomically create the caller's profile via the
    /// `create_user_profile` RPC. Server enforces auth + length +
    /// uniqueness. Returns the persisted profile.
    func create(displayName: String)
        async throws(UserProfileError) -> UserProfile

    /// Fetch the given user's profile. Returns nil if no profile row
    /// exists (legacy users pre-Phase-4, or freshly-signed-up users
    /// whose RPC call hasn't landed yet). Throws only on real
    /// persistence errors.
    func fetch(userID: UserID)
        async throws(UserProfileError) -> UserProfile?
}

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

    /// Upsert the caller's display name via the `update_user_profile`
    /// RPC. Creates the row if the caller had none (legacy / partial
    /// signup), otherwise overwrites it. Server enforces auth + length.
    /// Returns the persisted profile.
    func update(displayName: String)
        async throws(UserProfileError) -> UserProfile
}

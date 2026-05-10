import Foundation

/// PostgREST decoding shape for the `user_profiles` table + the
/// `create_user_profile` RPC return.
struct UserProfileDTO: Codable, Sendable {
    let userId: UUID
    let displayName: String
    let createdAt: String         // ISO 8601 from TIMESTAMPTZ
    let updatedAt: String
}

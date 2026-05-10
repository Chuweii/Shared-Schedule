import Foundation
import PostgREST

enum UserProfileMapper {

    static func toDomain(_ dto: UserProfileDTO) -> UserProfile? {
        try? UserProfile(
            userID: UserID(dto.userId.uuidString.lowercased()),
            displayName: dto.displayName
        )
    }

    /// Maps `create_user_profile`'s `RAISE EXCEPTION '<code>'` strings
    /// to the typed Domain enum. Substring match against
    /// `localizedDescription` mirrors `BookingMapper.mapBookError` —
    /// robust to Postgres's `unhandled_exception` prefix when no
    /// SQLSTATE is attached.
    static func mapCreateError(_ pg: PostgrestError) -> UserProfileError {
        let message = pg.localizedDescription
        if message.contains("INVALID_DISPLAY_NAME") { return .invalidDisplayName }
        if message.contains("ALREADY_EXISTS") { return .alreadyExists }
        return .persistenceFailure
    }
}

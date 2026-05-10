import Foundation

/// Per-user editable profile (Phase 4 Slice A). Currently holds only
/// `displayName` — first surface for the human-readable identity used in
/// owner-side booking rows. Future fields (avatar URL, bio) will live
/// here too.
nonisolated struct UserProfile: Sendable, Equatable {
    let userID: UserID
    let displayName: String

    init(userID: UserID, displayName: String) throws(UserProfileError) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .invalidDisplayName }
        guard trimmed.count <= 50 else { throw .invalidDisplayName }
        self.userID = userID
        self.displayName = trimmed
    }
}

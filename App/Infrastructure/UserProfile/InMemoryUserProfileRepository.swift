import Foundation

/// Used by `AppDependencies.live` for SwiftUI previews. Production code
/// path (RootView) wires `SupabaseUserProfileRepository` directly.
nonisolated final class InMemoryUserProfileRepository: UserProfileRepositoryProtocol, @unchecked Sendable {
    private var store: [UserID: UserProfile] = [:]

    func create(displayName: String)
        async throws(UserProfileError) -> UserProfile
    {
        let userID = UserID("preview-user")
        if store[userID] != nil {
            throw .alreadyExists
        }
        let profile: UserProfile
        do {
            profile = try UserProfile(userID: userID, displayName: displayName)
        } catch {
            throw .invalidDisplayName
        }
        store[userID] = profile
        return profile
    }

    func fetch(userID: UserID)
        async throws(UserProfileError) -> UserProfile?
    {
        store[userID]
    }

    func update(displayName: String)
        async throws(UserProfileError) -> UserProfile
    {
        let userID = UserID("preview-user")
        let profile: UserProfile
        do {
            profile = try UserProfile(userID: userID, displayName: displayName)
        } catch {
            throw .invalidDisplayName
        }
        store[userID] = profile
        return profile
    }
}

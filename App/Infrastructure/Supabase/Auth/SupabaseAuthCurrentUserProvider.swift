import Auth
import Foundation
import OSLog

private let log = Logger(subsystem: "com.Kyoi.Shared-Schedule", category: "Auth")

final class SupabaseAuthCurrentUserProvider: CurrentUserProviderProtocol, @unchecked Sendable {
    private var cachedUser: User?
    private let userProfileRepository: any UserProfileRepositoryProtocol

    init(userProfileRepository: any UserProfileRepositoryProtocol) {
        self.userProfileRepository = userProfileRepository
    }

    var currentUser: User {
        guard let user = cachedUser else {
            fatalError("No authenticated user — login gate should prevent this")
        }
        return user
    }

    /// Hydrates `currentUser` after a successful sign-in. Fetches the
    /// caller's `user_profiles` row to resolve `displayName`; on miss
    /// (legacy users, or freshly signed-up users whose
    /// `create_user_profile` RPC hasn't landed yet) falls back to email
    /// so the UI never blocks on a profile-creation race.
    ///
    /// `UserID` keeps Foundation's default UPPERCASE form so that
    /// equality comparisons against `Schedule.ownerID` (which goes
    /// through ScheduleMapper using the same uppercase form) work for
    /// the `isOwner` branch in calendar / toolbar code. PostgREST UUID
    /// equality is case-insensitive, so the lowercase profile rows in
    /// Postgres are still findable via this uppercase UserID.
    func update(from authUser: Auth.User) async {
        let userID = UserID(authUser.id.uuidString)
        let displayName: String
        do {
            if let profile = try await userProfileRepository.fetch(userID: userID) {
                displayName = profile.displayName
            } else {
                displayName = authUser.email ?? ""
                log.info("no user_profiles row for \(authUser.id.uuidString, privacy: .public); falling back to email displayName")
            }
        } catch {
            displayName = authUser.email ?? ""
            log.error("user_profiles fetch failed: \(error.localizedDescription, privacy: .public); falling back to email displayName")
        }
        cachedUser = User(id: userID, displayName: displayName)
    }

    func updateCachedDisplayName(_ displayName: String) {
        guard let user = cachedUser else { return }
        cachedUser = User(id: user.id, displayName: displayName)
    }

    func clear() {
        cachedUser = nil
    }
}

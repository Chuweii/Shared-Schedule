import Auth
import Foundation

final class SupabaseAuthCurrentUserProvider: CurrentUserProviderProtocol, @unchecked Sendable {
    private var cachedUser: User?

    init() {}

    var currentUser: User {
        guard let user = cachedUser else {
            fatalError("No authenticated user — login gate should prevent this")
        }
        return user
    }

    func update(from authUser: Auth.User) {
        cachedUser = User(
            id: UserID(authUser.id.uuidString),
            displayName: authUser.email ?? ""
        )
    }

    func clear() {
        cachedUser = nil
    }
}

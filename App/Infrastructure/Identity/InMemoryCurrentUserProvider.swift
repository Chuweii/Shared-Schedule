nonisolated final class InMemoryCurrentUserProvider: CurrentUserProviderProtocol, @unchecked Sendable {
    private var user = User(
        id: UserID("teacher-001"),
        displayName: "測試老師"
    )

    var currentUser: User { user }

    func updateCachedDisplayName(_ displayName: String) {
        user = User(id: user.id, displayName: displayName)
    }
}

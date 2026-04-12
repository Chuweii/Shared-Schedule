nonisolated struct InMemoryCurrentUserProvider: CurrentUserProviderProtocol {
    let currentUser = User(
        id: UserID("teacher-001"),
        displayName: "測試老師"
    )
}

protocol CurrentUserProviderProtocol: Sendable {
    var currentUser: User { get }

    /// Update the cached user's display name after the user edits it in
    /// settings, so screens that re-read `currentUser` (e.g. reopening
    /// settings) reflect the change without a full re-sign-in.
    func updateCachedDisplayName(_ displayName: String)
}

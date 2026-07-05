protocol UpdateDisplayNameUseCaseProtocol: Sendable {
    /// Validate the new display name (non-empty, <= 50 chars after trim)
    /// then upsert it via the profile repository. Returns the persisted
    /// profile.
    func updateDisplayName(_ displayName: String)
        async throws(UpdateDisplayNameError) -> UserProfile
}

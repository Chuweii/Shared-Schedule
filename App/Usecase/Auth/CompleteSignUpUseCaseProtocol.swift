protocol CompleteSignUpUseCaseProtocol: Sendable {
    /// Atomic from the VM's perspective: signs up via Supabase Auth
    /// then creates the profile. Both must succeed; profile-create
    /// failures after auth-signup success surface as `.partialFailure`.
    /// `.alreadyExists` from the profile repo is treated as success
    /// (retry race after a previous partial-failure attempt).
    func completeSignUp(email: String, password: String, displayName: String)
        async throws(CompleteSignUpError)
}

protocol RedeemInvitationUseCaseProtocol: Sendable {
    /// Redeem an invitation token on behalf of the current authenticated
    /// user, returning the joined `Schedule` for the success UX. Wraps the
    /// Repository's RPC call and an immediate Schedule fetch so the
    /// ViewModel can render the schedule's title without a second round-trip.
    func redeemInvitation(token: InvitationToken)
        async throws(InvitationRedemptionError) -> Schedule
}

/// Outcomes of `InvitationRepositoryProtocol.redeem`. Modeled in Domain so
/// the Repository protocol's typed throw stays Infrastructure-agnostic and
/// Usecase / Presentation can pattern-match on the same enum without
/// importing PostgREST.
nonisolated enum InvitationRedemptionError: Error, Equatable, Sendable {
    case invalidToken
    case expired
    case selfRedemption
    case alreadyMember
    case persistenceFailure
}

import Foundation

/// Hybrid membership model: only students live in `memberships`. The
/// teacher's "role" is implied by `Schedule.ownerID`. Cross-aggregate
/// invariants (uniqueness per (schedule, user); selfRedemption guard)
/// live in the backend (`UNIQUE` constraint + `redeem_invitation` RPC),
/// not in this struct.
nonisolated struct Membership: Sendable, Equatable {
    let id: MembershipID
    let scheduleID: ScheduleID
    let userID: UserID
    let invitationID: InvitationID?
    let joinedAt: Date

    init(
        id: MembershipID = MembershipID(),
        scheduleID: ScheduleID,
        userID: UserID,
        invitationID: InvitationID? = nil,
        joinedAt: Date = Date()
    ) {
        self.id = id
        self.scheduleID = scheduleID
        self.userID = userID
        self.invitationID = invitationID
        self.joinedAt = joinedAt
    }
}

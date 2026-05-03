import Foundation

/// Result of a successful `redeem_invitation` RPC call: the schedule the
/// invitation belonged to, the membership row that was just inserted, and
/// the server-side timestamp. Repository contract — Usecase typically
/// follows up with a Schedule fetch for richer display data.
nonisolated struct InvitationRedemption: Sendable, Equatable {
    let scheduleID: ScheduleID
    let membershipID: MembershipID
    let joinedAt: Date

    init(scheduleID: ScheduleID, membershipID: MembershipID, joinedAt: Date) {
        self.scheduleID = scheduleID
        self.membershipID = membershipID
        self.joinedAt = joinedAt
    }
}

import Foundation

nonisolated struct Invitation: Sendable, Equatable {
    static let defaultExpiryDuration: TimeInterval = 60 * 60 * 24 * 7  // 7 days

    let id: InvitationID
    let scheduleID: ScheduleID
    let token: InvitationToken
    let expiresAt: Date
    let createdAt: Date

    init(
        id: InvitationID = InvitationID(),
        scheduleID: ScheduleID,
        token: InvitationToken = InvitationToken.generate(),
        expiresAt: Date,
        createdAt: Date = Date()
    ) throws(InvitationError) {
        guard expiresAt > createdAt else {
            throw .invalidExpiry
        }
        self.id = id
        self.scheduleID = scheduleID
        self.token = token
        self.expiresAt = expiresAt
        self.createdAt = createdAt
    }

    func isExpired(at now: Date) -> Bool {
        now >= expiresAt
    }
}

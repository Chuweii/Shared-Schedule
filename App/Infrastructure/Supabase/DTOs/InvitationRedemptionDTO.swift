import Foundation

struct InvitationRedemptionDTO: Codable, Sendable {
    let scheduleId: UUID
    let membershipId: UUID
    let joinedAt: String   // ISO 8601 from Postgres TIMESTAMPTZ
}

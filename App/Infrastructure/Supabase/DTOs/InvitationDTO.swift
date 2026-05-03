import Foundation

struct InvitationDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let token: String
    let expiresAt: String   // ISO 8601 from Postgres TIMESTAMPTZ
    let createdAt: String?
}

struct InvitationInsertDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let token: String
    let expiresAt: String
}

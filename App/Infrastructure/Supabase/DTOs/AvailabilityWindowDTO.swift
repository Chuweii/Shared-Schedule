import Foundation

struct AvailabilityWindowDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let startAt: String  // ISO 8601 from Postgres TIMESTAMPTZ
    let endAt: String    // ISO 8601
}

struct AvailabilityWindowInsertDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let startAt: String
    let endAt: String
}

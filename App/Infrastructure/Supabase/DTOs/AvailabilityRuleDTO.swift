import Foundation

struct AvailabilityRuleDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let weekday: Int
    let startTime: String  // "HH:MM:SS" from Postgres TIME
    let endTime: String    // "HH:MM:SS"
}

struct AvailabilityRuleInsertDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let weekday: Int
    let startTime: String
    let endTime: String
}

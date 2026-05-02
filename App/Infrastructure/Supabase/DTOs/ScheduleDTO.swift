import Foundation

struct ScheduleDTO: Codable, Sendable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let minWindowDuration: Int
    let createdAt: String?
    let updatedAt: String?
    let availabilityRules: [AvailabilityRuleDTO]?
    let availabilityWindows: [AvailabilityWindowDTO]?
}

struct ScheduleInsertDTO: Codable, Sendable {
    let id: UUID
    let ownerId: UUID
    let title: String
    let minWindowDuration: Int
}

import Foundation

/// Mirrors the `bookings` table row shape and is also the return shape of
/// the `book_slot` RPC (RETURNS TABLE(...) with the same columns).
struct BookingDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let studentId: UUID
    let startsAt: String         // ISO 8601 from Postgres TIMESTAMPTZ
    let endsAt: String
    let durationSeconds: Int
    let createdAt: String
}

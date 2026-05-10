import Foundation

/// Return shape of the `get_bookings_for_owner` RPC. Mirrors `BookingDTO`
/// + a `student_email` column joined from `auth.users`.
struct OwnerBookingDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let studentId: UUID
    let studentEmail: String
    let startsAt: String
    let endsAt: String
    let durationSeconds: Int
    let createdAt: String
}

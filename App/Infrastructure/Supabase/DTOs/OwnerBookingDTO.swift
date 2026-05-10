import Foundation

/// Return shape of the `get_bookings_for_owner` RPC. Mirrors `BookingDTO`
/// + a `student_email` column joined from `auth.users` and (Phase 4
/// Slice A) a `student_display_name` column LEFT-JOINed from
/// `user_profiles`. The display name is nullable when the student has
/// no profile row yet (legacy / partial signup).
struct OwnerBookingDTO: Codable, Sendable {
    let id: UUID
    let scheduleId: UUID
    let studentId: UUID
    let studentEmail: String
    let studentDisplayName: String?
    let startsAt: String
    let endsAt: String
    let durationSeconds: Int
    let createdAt: String
}

import Foundation

/// Return shape of the `get_bookings_visible_to_member` RPC (Slice 2).
/// Sanitized to three fields — no booking_id, student_id, or email — so
/// even if a future caller accidentally requests `*` they cannot leak PII.
struct BookedSlotDTO: Codable, Sendable {
    let startsAt: String         // ISO 8601 from TIMESTAMPTZ
    let endsAt: String
    let durationSeconds: Int
}

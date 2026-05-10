import Foundation

/// VM-side rendering value for a single calendar slot. Combines the
/// rule-derived `ComputedSlot` (start/end) with whatever booking state
/// applies to the current student. The View renders different row
/// styles based on `state`.
struct PresentedSlot: Identifiable, Sendable, Equatable {
    let id: String
    let slot: ComputedSlot
    let state: SlotPresentationState
}

enum SlotPresentationState: Sendable, Equatable {
    case available
    /// Student view: this slot is the current student's own booking.
    case mineBooked(BookingID)
    /// Owner view: this slot is booked by some student. `displayName`
    /// surfaces from `user_profiles` when present (Phase 4 Slice A);
    /// View falls back to `email` otherwise. Not visible to other
    /// students.
    case bookedByStudent(displayName: String?, email: String)
    /// Student view (Slice 2): this slot is booked by another student.
    /// No payload by design — the row renders time-only "已被預約" with
    /// no booking_id / student_id / email leaking through.
    case bookedByOther
}

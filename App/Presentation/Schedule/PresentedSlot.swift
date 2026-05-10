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
    /// Owner view: this slot is booked by some student. Email surfaces
    /// in the owner-only owner row UI; not visible to other students.
    case bookedByStudent(email: String)
}

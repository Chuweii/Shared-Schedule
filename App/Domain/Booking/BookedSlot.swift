import Foundation

/// Sanitized representation of a slot already booked by *some other* student.
/// Carries no booking_id, student_id, or email — the type system prevents
/// accidentally surfacing PII in cross-student visibility paths (Slice 2).
nonisolated struct BookedSlot: Sendable, Equatable {
    let startsAt: Date
    let endsAt: Date
    let durationSeconds: Int

    init(
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int
    ) throws(BookingError) {
        guard endsAt > startsAt else {
            throw .invalidRange
        }
        guard durationSeconds > 0 else {
            throw .invalidDuration
        }
        let elapsed = endsAt.timeIntervalSince(startsAt)
        guard abs(elapsed - TimeInterval(durationSeconds)) < 1 else {
            throw .durationMismatch
        }
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.durationSeconds = durationSeconds
    }

    func matches(_ slot: ComputedSlot) -> Bool {
        let startMatch = abs(startsAt.timeIntervalSince(slot.start)) < 1
        let slotDuration = slot.end.timeIntervalSince(slot.start)
        let durationMatch = abs(slotDuration - TimeInterval(durationSeconds)) < 1
        return startMatch && durationMatch
    }
}

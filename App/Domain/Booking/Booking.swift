import Foundation

nonisolated struct Booking: Sendable, Equatable {
    let id: BookingID
    let scheduleID: ScheduleID
    let studentID: UserID
    let startsAt: Date
    let endsAt: Date
    let durationSeconds: Int
    let createdAt: Date

    init(
        id: BookingID = BookingID(),
        scheduleID: ScheduleID,
        studentID: UserID,
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int,
        createdAt: Date = Date()
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
        self.id = id
        self.scheduleID = scheduleID
        self.studentID = studentID
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.durationSeconds = durationSeconds
        self.createdAt = createdAt
    }

    func matches(_ slot: ComputedSlot) -> Bool {
        let startMatch = abs(startsAt.timeIntervalSince(slot.start)) < 1
        let slotDuration = slot.end.timeIntervalSince(slot.start)
        let durationMatch = abs(slotDuration - TimeInterval(durationSeconds)) < 1
        return startMatch && durationMatch
    }
}

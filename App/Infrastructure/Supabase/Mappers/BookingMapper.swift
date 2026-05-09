import Foundation
import PostgREST

enum BookingMapper {

    static func toDomain(_ dto: BookingDTO) -> Booking? {
        guard
            let startsAt = ScheduleMapper.parseTimestamptz(dto.startsAt),
            let endsAt = ScheduleMapper.parseTimestamptz(dto.endsAt),
            let createdAt = ScheduleMapper.parseTimestamptz(dto.createdAt)
        else { return nil }

        return try? Booking(
            id: BookingID(dto.id),
            scheduleID: ScheduleID(dto.scheduleId),
            studentID: UserID(dto.studentId.uuidString.lowercased()),
            startsAt: startsAt,
            endsAt: endsAt,
            durationSeconds: dto.durationSeconds,
            createdAt: createdAt
        )
    }

    /// Maps `book_slot`'s `RAISE EXCEPTION '<code>'` strings to the typed
    /// Domain enum. Substring match against `localizedDescription` mirrors
    /// the InvitationRepository pattern — robust to Postgres's
    /// `unhandled_exception` prefix when no SQLSTATE is attached.
    static func mapBookError(_ pg: PostgrestError) -> CreateBookingError {
        let message = pg.localizedDescription
        if message.contains("SLOT_TAKEN") { return .slotTaken }
        if message.contains("OWNER_CANNOT_BOOK") { return .ownerCannotBook }
        if message.contains("NOT_MEMBER") { return .notMember }
        if message.contains("PAST_SLOT") { return .slotInPast }
        if message.contains("SCHEDULE_NOT_FOUND") { return .scheduleNotFound }
        return .persistenceFailure
    }

    static func mapCancelError(_ pg: PostgrestError) -> CancelBookingError {
        let message = pg.localizedDescription
        if message.contains("BOOKING_NOT_FOUND") { return .bookingNotFound }
        if message.contains("NOT_OWNER") { return .notOwner }
        if message.contains("SLOT_STARTED") { return .slotAlreadyStarted }
        return .persistenceFailure
    }
}

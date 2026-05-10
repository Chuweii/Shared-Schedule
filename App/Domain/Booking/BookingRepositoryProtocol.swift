import Foundation

protocol BookingRepositoryProtocol: Sendable {
    /// Atomically create a booking via the `book_slot` Postgres RPC.
    /// Server enforces auth, range/duration sanity, future-only, owner
    /// rejection, membership, and the UNIQUE(schedule_id, starts_at)
    /// conflict (mapped to `.slotTaken`).
    func create(
        scheduleID: ScheduleID,
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int
    ) async throws(CreateBookingError) -> Booking

    /// Atomically cancel a booking via the `cancel_booking` RPC. Server
    /// enforces auth, ownership (caller must be the booking's student),
    /// and the cannot-cancel-after-starts cutoff.
    func cancel(id: BookingID) async throws(CancelBookingError)

    /// All bookings the given student has on the given schedule.
    /// RLS ensures non-members see [].
    func fetchAll(
        scheduleID: ScheduleID,
        studentID: UserID
    ) async throws -> [Booking]

    /// Owner-only: all bookings on the schedule, augmented with the
    /// student's email. Backed by the `get_bookings_for_owner` RPC,
    /// which `RAISE EXCEPTION 'NOT_OWNER'` for callers who do not own
    /// the schedule.
    func fetchAllForOwner(
        scheduleID: ScheduleID
    ) async throws(ListAllBookingsForOwnerError) -> [OwnerBooking]
}

import Foundation

/// Used by `AppDependencies.live` for SwiftUI previews. Production code path
/// (RootView) wires `SupabaseBookingRepository` directly.
///
/// `create` and `cancel` are simulated against the local store with a fixed
/// student id ("preview-student") since there is no real auth identity in
/// previews; previews that exercise booking flows should wire fake usecases
/// at the ViewModel boundary instead.
nonisolated final class InMemoryBookingRepository: BookingRepositoryProtocol, @unchecked Sendable {
    private var store: [BookingID: Booking] = [:]

    func create(
        scheduleID: ScheduleID,
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int
    ) async throws(CreateBookingError) -> Booking {
        let booking: Booking
        do {
            booking = try Booking(
                scheduleID: scheduleID,
                studentID: UserID("preview-student"),
                startsAt: startsAt,
                endsAt: endsAt,
                durationSeconds: durationSeconds
            )
        } catch {
            throw .persistenceFailure
        }
        if store.values.contains(where: {
            $0.scheduleID == scheduleID && $0.startsAt == startsAt
        }) {
            throw .slotTaken
        }
        store[booking.id] = booking
        return booking
    }

    func cancel(id: BookingID) async throws(CancelBookingError) {
        guard store[id] != nil else { throw .bookingNotFound }
        store[id] = nil
    }

    func fetchAll(
        scheduleID: ScheduleID,
        studentID: UserID
    ) async throws -> [Booking] {
        store.values
            .filter { $0.scheduleID == scheduleID && $0.studentID == studentID }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func fetchAllForOwner(
        scheduleID: ScheduleID
    ) async throws(ListAllBookingsForOwnerError) -> [OwnerBooking] {
        // Preview-only: there's no real auth identity, so we can't tell
        // who is "owner". Return everything on the schedule as if the
        // caller were the owner; previews that need permission semantics
        // should wire fake usecases at the ViewModel boundary.
        store.values
            .filter { $0.scheduleID == scheduleID }
            .sorted { $0.startsAt < $1.startsAt }
            .map { OwnerBooking(booking: $0, studentEmail: "preview@example.com") }
    }
}

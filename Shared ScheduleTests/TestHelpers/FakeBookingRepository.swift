import Foundation
@testable import Shared_Schedule

/// Test double mirroring FakeInvitationRepository's pattern. Stores
/// bookings in memory keyed by id; create/cancel/fetchAll can be forced
/// to throw arbitrary typed errors so tests can drive every error
/// branch of the usecases without a real backend.
final class FakeBookingRepository: BookingRepositoryProtocol, @unchecked Sendable {

    /// The studentID that successful `create` calls stamp on the returned
    /// Booking. Defaults to "teacher-001" so it matches the default
    /// `InMemoryCurrentUserProvider` user for usecase tests that don't
    /// care about the value.
    var studentIDForCreate: UserID

    private var store: [BookingID: Booking] = [:]

    var createError: CreateBookingError?
    var cancelError: CancelBookingError?
    var fetchAllError: Error?
    var fetchAllForOwnerError: ListAllBookingsForOwnerError?
    var fetchAllForOwnerResult: [OwnerBooking] = []
    var fetchOthersBookingsError: ListOthersBookingsError?
    var fetchOthersBookingsResult: [BookedSlot] = []

    private(set) var createCount = 0
    private(set) var cancelCount = 0
    private(set) var fetchAllCount = 0
    private(set) var fetchAllForOwnerCount = 0
    private(set) var fetchOthersBookingsCount = 0
    private(set) var lastCreateParams: (
        scheduleID: ScheduleID,
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int
    )?
    private(set) var lastCancelID: BookingID?
    private(set) var lastFetchAllParams: (scheduleID: ScheduleID, studentID: UserID)?
    private(set) var lastFetchAllForOwnerScheduleID: ScheduleID?
    private(set) var lastFetchOthersBookingsScheduleID: ScheduleID?

    init(studentIDForCreate: UserID = UserID("teacher-001")) {
        self.studentIDForCreate = studentIDForCreate
    }

    func create(
        scheduleID: ScheduleID,
        startsAt: Date,
        endsAt: Date,
        durationSeconds: Int
    ) async throws(CreateBookingError) -> Booking {
        createCount += 1
        lastCreateParams = (scheduleID, startsAt, endsAt, durationSeconds)
        if let createError { throw createError }
        let booking: Booking
        do {
            booking = try Booking(
                scheduleID: scheduleID,
                studentID: studentIDForCreate,
                startsAt: startsAt,
                endsAt: endsAt,
                durationSeconds: durationSeconds
            )
        } catch {
            throw .persistenceFailure
        }
        store[booking.id] = booking
        return booking
    }

    func cancel(id: BookingID) async throws(CancelBookingError) {
        cancelCount += 1
        lastCancelID = id
        if let cancelError { throw cancelError }
        store[id] = nil
    }

    func fetchAll(
        scheduleID: ScheduleID,
        studentID: UserID
    ) async throws -> [Booking] {
        fetchAllCount += 1
        lastFetchAllParams = (scheduleID, studentID)
        if let fetchAllError { throw fetchAllError }
        return store.values
            .filter { $0.scheduleID == scheduleID && $0.studentID == studentID }
            .sorted { $0.startsAt < $1.startsAt }
    }

    func fetchAllForOwner(
        scheduleID: ScheduleID
    ) async throws(ListAllBookingsForOwnerError) -> [OwnerBooking] {
        fetchAllForOwnerCount += 1
        lastFetchAllForOwnerScheduleID = scheduleID
        if let fetchAllForOwnerError { throw fetchAllForOwnerError }
        return fetchAllForOwnerResult
    }

    func fetchOthersBookings(
        scheduleID: ScheduleID
    ) async throws(ListOthersBookingsError) -> [BookedSlot] {
        fetchOthersBookingsCount += 1
        lastFetchOthersBookingsScheduleID = scheduleID
        if let fetchOthersBookingsError { throw fetchOthersBookingsError }
        return fetchOthersBookingsResult
    }

    func preload(_ bookings: [Booking]) {
        for booking in bookings { store[booking.id] = booking }
    }
}

enum FakeBookingRepositoryError: Error {
    case forced
}

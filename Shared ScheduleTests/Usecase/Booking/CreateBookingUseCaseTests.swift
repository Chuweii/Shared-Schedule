import Testing
import Foundation
@testable import Shared_Schedule

struct CreateBookingUseCaseTests {

    private static let teacher001 = UserID("teacher-001")
    private static let teacher002 = UserID("teacher-002")
    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()
    /// 2026-04-13 is a Monday in UTC.
    private static func mondayDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 13
        return utcCalendar.date(from: components)!
    }

    /// SUT with a schedule owned by `ownerID`, with one Monday rule
    /// 09:00–12:00 (3 one-hour slots), `now` returning a moment before
    /// the Monday slots start. Caller can override `now` for the
    /// past-slot test.
    private func makeSUT(
        ownerID: UserID = teacher002,
        now: Date? = nil
    ) async throws -> (
        useCase: CreateBookingUseCase,
        scheduleID: ScheduleID,
        firstSlot: ComputedSlot,
        bookingRepo: FakeBookingRepository,
        scheduleRepo: InMemoryScheduleRepository
    ) {
        let scheduleRepo = InMemoryScheduleRepository()
        let bookingRepo = FakeBookingRepository()
        let userProvider = InMemoryCurrentUserProvider()  // currentUser.id = teacher-001

        let scheduleID = ScheduleID()
        var schedule = Schedule(
            id: scheduleID,
            ownerID: ownerID,
            title: "Sample",
            minWindowDuration: 3600
        )
        try schedule.addRule(
            weekday: .monday,
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 12, minute: 0)
        )
        try await scheduleRepo.save(schedule)

        let slots = schedule.computedSlots(for: Self.mondayDate(), calendar: Self.utcCalendar)
        let firstSlot = slots[0]

        let nowDate = now ?? firstSlot.start.addingTimeInterval(-3600)  // 1 hour before slot
        let useCase = CreateBookingUseCase(
            scheduleRepository: scheduleRepo,
            bookingRepository: bookingRepo,
            currentUserProvider: userProvider,
            calendar: Self.utcCalendar,
            now: { nowDate }
        )
        return (useCase, scheduleID, firstSlot, bookingRepo, scheduleRepo)
    }

    // MARK: - BC1

    @Test("Member 對自己加入 schedule 上某未來 ComputedSlot 預約，repo.create 被呼叫一次、回傳 booking")
    func createBooking_memberFutureSlot_succeeds() async throws {
        // Given
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT()

        // When
        let booking = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)

        // Then
        #expect(bookingRepo.createCount == 1)
        #expect(bookingRepo.lastCreateParams?.scheduleID == scheduleID)
        #expect(bookingRepo.lastCreateParams?.startsAt == slot.start)
        #expect(bookingRepo.lastCreateParams?.endsAt == slot.end)
        #expect(bookingRepo.lastCreateParams?.durationSeconds == 3600)
        #expect(booking.scheduleID == scheduleID)
        #expect(booking.startsAt == slot.start)
    }

    // MARK: - BC2

    @Test("Repo.create 拋 .notMember（server-side race），usecase 透傳 .notMember")
    func createBooking_repoThrowsNotMember_passthrough() async throws {
        // Given
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT()
        bookingRepo.createError = .notMember

        // When / Then
        await #expect(throws: CreateBookingError.notMember) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)
        }
    }

    // MARK: - BC3

    @Test("Owner 對自己 schedule 嘗試預約，throws .ownerCannotBook、repo 未呼叫")
    func createBooking_ownerOwnSchedule_throwsOwnerCannotBook() async throws {
        // Given — schedule owned by teacher-001 (matches default currentUser)
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT(ownerID: Self.teacher001)

        // When / Then
        await #expect(throws: CreateBookingError.ownerCannotBook) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)
        }
        #expect(bookingRepo.createCount == 0)
    }

    // MARK: - BC4

    @Test("ScheduleID 不存在，throws .scheduleNotFound")
    func createBooking_nonExistentSchedule_throwsScheduleNotFound() async throws {
        // Given
        let scheduleRepo = InMemoryScheduleRepository()
        let bookingRepo = FakeBookingRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = CreateBookingUseCase(
            scheduleRepository: scheduleRepo,
            bookingRepository: bookingRepo,
            currentUserProvider: userProvider,
            calendar: Self.utcCalendar,
            now: { Self.mondayDate() }
        )
        let fakeID = ScheduleID()
        let slot = ComputedSlot(
            start: Self.mondayDate().addingTimeInterval(3600 * 9),
            end: Self.mondayDate().addingTimeInterval(3600 * 10)
        )

        // When / Then
        await #expect(throws: CreateBookingError.scheduleNotFound) {
            _ = try await useCase.createBooking(scheduleID: fakeID, slot: slot)
        }
    }

    // MARK: - BC5

    @Test("Slot.start 在 now 之前，throws .slotInPast、repo 未呼叫")
    func createBooking_pastSlot_throwsSlotInPast() async throws {
        // Given — now is 1 second AFTER the slot start
        let monday = Self.mondayDate()
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT(
            now: monday.addingTimeInterval(3600 * 9 + 1)
        )

        // When / Then
        await #expect(throws: CreateBookingError.slotInPast) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)
        }
        #expect(bookingRepo.createCount == 0)
    }

    // MARK: - BC6

    @Test("Slot 的 (start, end) 不對應任何 ComputedSlot，throws .slotNotInSchedule")
    func createBooking_slotNotInSchedule_throwsSlotNotInSchedule() async throws {
        // Given — a "slot" that's offset 30 minutes from any rule-derived slot
        let (useCase, scheduleID, validSlot, bookingRepo, _) = try await makeSUT()
        let bogusSlot = ComputedSlot(
            start: validSlot.start.addingTimeInterval(30 * 60),
            end: validSlot.end.addingTimeInterval(30 * 60)
        )

        // When / Then
        await #expect(throws: CreateBookingError.slotNotInSchedule) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: bogusSlot)
        }
        #expect(bookingRepo.createCount == 0)
    }

    // MARK: - BC7

    @Test("Repo.create 拋 .slotTaken，usecase 透傳")
    func createBooking_repoThrowsSlotTaken_passthrough() async throws {
        // Given
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT()
        bookingRepo.createError = .slotTaken

        // When / Then
        await #expect(throws: CreateBookingError.slotTaken) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)
        }
    }

    // MARK: - BC8

    @Test("Repo.create 拋 .persistenceFailure，usecase 透傳")
    func createBooking_repoThrowsPersistenceFailure_passthrough() async throws {
        // Given
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT()
        bookingRepo.createError = .persistenceFailure

        // When / Then
        await #expect(throws: CreateBookingError.persistenceFailure) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)
        }
    }

    // MARK: - BC9

    @Test("ScheduleRepository.fetch 拋錯，throws .persistenceFailure")
    func createBooking_scheduleFetchFails_throwsPersistenceFailure() async throws {
        // Given
        let scheduleRepo = ThrowingScheduleRepository()
        let bookingRepo = FakeBookingRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = CreateBookingUseCase(
            scheduleRepository: scheduleRepo,
            bookingRepository: bookingRepo,
            currentUserProvider: userProvider,
            calendar: Self.utcCalendar,
            now: { Self.mondayDate() }
        )
        let slot = ComputedSlot(
            start: Self.mondayDate().addingTimeInterval(3600 * 9),
            end: Self.mondayDate().addingTimeInterval(3600 * 10)
        )

        // When / Then
        await #expect(throws: CreateBookingError.persistenceFailure) {
            _ = try await useCase.createBooking(scheduleID: ScheduleID(), slot: slot)
        }
    }

    // MARK: - BC10

    @Test("Repo.create 拋 .scheduleNotFound（server-side race），usecase 透傳")
    func createBooking_repoThrowsScheduleNotFound_passthrough() async throws {
        // Given
        let (useCase, scheduleID, slot, bookingRepo, _) = try await makeSUT()
        bookingRepo.createError = .scheduleNotFound

        // When / Then
        await #expect(throws: CreateBookingError.scheduleNotFound) {
            _ = try await useCase.createBooking(scheduleID: scheduleID, slot: slot)
        }
    }
}

/// Local test double — InMemoryScheduleRepository's fetch never throws,
/// so we need this to drive BC9's "fetch raises an error" branch.
private final class ThrowingScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {
    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule] { [] }
    func fetchAll(memberOf userID: UserID) async throws -> [Schedule] { [] }
    func fetch(id: ScheduleID) async throws -> Schedule? {
        throw FakeBookingRepositoryError.forced
    }
    func save(_ schedule: Schedule) async throws {}
}

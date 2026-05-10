import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct ScheduleCalendarViewModelTests {

    private static let utcCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 1 // Sunday
        return cal
    }()

    private func makeScheduleWithMondayRule() throws -> Schedule {
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階",
            minWindowDuration: 3600
        )
        try schedule.addRule(
            weekday: .monday,
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 18, minute: 0)
        )
        return schedule
    }

    private func makeSUT(schedule: Schedule, referenceDate: Date? = nil) -> ScheduleCalendarViewModel {
        ScheduleCalendarViewModel(
            schedule: schedule,
            calendar: Self.utcCalendar,
            referenceDate: referenceDate ?? Self.date(year: 2026, month: 4, day: 1)
        )
    }

    private static func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return utcCalendar.date(from: components)!
    }

    // MARK: - Tests

    @Test("onAppear 載入當月日期矩陣")
    func onAppear_loadsCurrentMonthDays() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let vm = makeSUT(schedule: schedule, referenceDate: Self.date(year: 2026, month: 4, day: 1))

        // When
        await vm.onAppear()

        // Then
        #expect(!vm.days.isEmpty)
        let currentMonthDays = vm.days.filter(\.isCurrentMonth)
        #expect(currentMonthDays.count == 30) // April 2026 has 30 days
    }

    @Test("選擇有 rule 的日期 → computedSlots 有值")
    func selectDate_withRule_hasSlots() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let vm = makeSUT(schedule: schedule, referenceDate: Self.date(year: 2026, month: 4, day: 1))
        await vm.onAppear()
        let monday = Self.date(year: 2026, month: 4, day: 13) // Monday

        // When
        vm.selectDate(monday)

        // Then
        #expect(vm.selectedDate == monday)
        #expect(vm.selectedDaySlots.count == 9) // 9-18, 60min each
    }

    @Test("選擇沒有 rule 的日期 → computedSlots 為空")
    func selectDate_withoutRule_emptySlots() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let vm = makeSUT(schedule: schedule, referenceDate: Self.date(year: 2026, month: 4, day: 1))
        await vm.onAppear()
        let wednesday = Self.date(year: 2026, month: 4, day: 15) // Wednesday

        // When
        vm.selectDate(wednesday)

        // Then
        #expect(vm.selectedDate == wednesday)
        #expect(vm.selectedDaySlots.isEmpty)
    }

    @Test("切換到上個月")
    func changeMonth_backward_updatesDays() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let vm = makeSUT(schedule: schedule, referenceDate: Self.date(year: 2026, month: 4, day: 1))
        await vm.onAppear()

        // When
        vm.changeMonth(by: -1)

        // Then
        let components = Self.utcCalendar.dateComponents([.year, .month], from: vm.currentMonth)
        #expect(components.month == 3)
        #expect(components.year == 2026)
        #expect(!vm.days.isEmpty)
        #expect(vm.selectedDate == nil)
    }

    @Test("切換到下個月")
    func changeMonth_forward_updatesDays() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let vm = makeSUT(schedule: schedule, referenceDate: Self.date(year: 2026, month: 4, day: 1))
        await vm.onAppear()

        // When
        vm.changeMonth(by: 1)

        // Then
        let components = Self.utcCalendar.dateComponents([.year, .month], from: vm.currentMonth)
        #expect(components.month == 5)
        #expect(components.year == 2026)
        #expect(!vm.days.isEmpty)
        #expect(vm.selectedDate == nil)
    }

    // MARK: - Booking helpers

    private static let teacher001 = UserID("teacher-001")

    private func makeBookingSUT(
        schedule: Schedule,
        listResult: [Booking] = [],
        listError: ListMyBookingsError? = nil
    ) -> (
        vm: ScheduleCalendarViewModel,
        listFake: FakeListMyBookingsUseCase,
        createFake: FakeCreateBookingUseCase,
        cancelFake: FakeCancelBookingUseCase
    ) {
        let listFake = FakeListMyBookingsUseCase()
        listFake.resultToReturn = listResult
        listFake.errorToThrow = listError
        let createFake = FakeCreateBookingUseCase()
        let cancelFake = FakeCancelBookingUseCase()
        let vm = ScheduleCalendarViewModel(
            schedule: schedule,
            calendar: Self.utcCalendar,
            referenceDate: Self.date(year: 2026, month: 4, day: 1),
            listMyBookingsUseCase: listFake,
            createBookingUseCase: createFake,
            cancelBookingUseCase: cancelFake
        )
        return (vm, listFake, createFake, cancelFake)
    }

    /// Construct a Booking matching a 1-hour slot starting at the given UTC date.
    private static func booking(at start: Date, scheduleID: ScheduleID) throws -> Booking {
        try Booking(
            scheduleID: scheduleID,
            studentID: teacher001,
            startsAt: start,
            endsAt: start.addingTimeInterval(3600),
            durationSeconds: 3600
        )
    }

    // MARK: - BCV1

    @Test("BCV1. onAppear，listMyBookings 回 0 筆 → 所有 slot 為 available")
    func onAppear_zeroBookings_allSlotsAvailable() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let (vm, listFake, _, _) = makeBookingSUT(schedule: schedule)
        let monday = Self.date(year: 2026, month: 4, day: 13)

        // When
        await vm.onAppear()
        vm.selectDate(monday)

        // Then
        #expect(listFake.callCount == 1)
        #expect(vm.myBookings.isEmpty)
        let presented = vm.presentedSlotsForSelectedDate
        #expect(presented.count == 9)
        #expect(presented.allSatisfy { $0.state == .available })
    }

    // MARK: - BCV2

    @Test("BCV2. onAppear，listMyBookings 回 1 筆 → 對應 slot 為 .mineBooked，其餘 .available")
    func onAppear_oneBooking_matchingSlotIsMineBooked() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let monday = Self.date(year: 2026, month: 4, day: 13)
        let mondayNineAM = monday.addingTimeInterval(9 * 3600)
        let myBooking = try Self.booking(at: mondayNineAM, scheduleID: schedule.id)
        let (vm, _, _, _) = makeBookingSUT(schedule: schedule, listResult: [myBooking])

        // When
        await vm.onAppear()
        vm.selectDate(monday)

        // Then
        let presented = vm.presentedSlotsForSelectedDate
        #expect(presented.count == 9)
        let nineAMRow = try #require(presented.first { $0.slot.start == mondayNineAM })
        #expect(nineAMRow.state == .mineBooked(myBooking.id))
        let others = presented.filter { $0.slot.start != mondayNineAM }
        #expect(others.allSatisfy { $0.state == .available })
    }

    // MARK: - BCV3

    @Test("BCV3. bookSlot 成功 → 對應 slot 變 .mineBooked、myBookings 多 1、inlineError 清空")
    func bookSlot_succeeds_marksSlotMineBookedAndAppendsBooking() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let monday = Self.date(year: 2026, month: 4, day: 13)
        let mondayTenAM = monday.addingTimeInterval(10 * 3600)
        let resultingBooking = try Self.booking(at: mondayTenAM, scheduleID: schedule.id)
        let (vm, _, createFake, _) = makeBookingSUT(schedule: schedule)
        createFake.resultToReturn = resultingBooking
        await vm.onAppear()
        vm.selectDate(monday)
        let targetSlot = ComputedSlot(start: mondayTenAM, end: mondayTenAM.addingTimeInterval(3600))

        // When
        await vm.bookSlot(targetSlot)

        // Then
        #expect(createFake.callCount == 1)
        #expect(vm.myBookings.count == 1)
        #expect(vm.myBookings.first?.id == resultingBooking.id)
        #expect(vm.inlineError == nil)
        let presented = vm.presentedSlotsForSelectedDate
        let tenAMRow = try #require(presented.first { $0.slot.start == mondayTenAM })
        #expect(tenAMRow.state == .mineBooked(resultingBooking.id))
    }

    // MARK: - BCV4

    @Test("BCV4. bookSlot 失敗 .slotTaken → inlineError 設定、slot 維持 .available")
    func bookSlot_fails_slotTaken_setsInlineErrorAndKeepsSlotAvailable() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let monday = Self.date(year: 2026, month: 4, day: 13)
        let mondayElevenAM = monday.addingTimeInterval(11 * 3600)
        let (vm, _, createFake, _) = makeBookingSUT(schedule: schedule)
        createFake.errorToThrow = .slotTaken
        await vm.onAppear()
        vm.selectDate(monday)
        let targetSlot = ComputedSlot(start: mondayElevenAM, end: mondayElevenAM.addingTimeInterval(3600))

        // When
        await vm.bookSlot(targetSlot)

        // Then
        #expect(vm.inlineError != nil)
        #expect(vm.myBookings.isEmpty)
        let presented = vm.presentedSlotsForSelectedDate
        let elevenAMRow = try #require(presented.first { $0.slot.start == mondayElevenAM })
        #expect(elevenAMRow.state == .available)
    }

    // MARK: - BCV5

    @Test("BCV5. cancelBooking 成功 → 對應 slot 變 .available、myBookings 少 1")
    func cancelBooking_succeeds_revertsSlotToAvailable() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let monday = Self.date(year: 2026, month: 4, day: 13)
        let mondayNineAM = monday.addingTimeInterval(9 * 3600)
        let myBooking = try Self.booking(at: mondayNineAM, scheduleID: schedule.id)
        let (vm, _, _, cancelFake) = makeBookingSUT(schedule: schedule, listResult: [myBooking])
        await vm.onAppear()
        vm.selectDate(monday)

        // When
        await vm.cancelBooking(myBooking.id)

        // Then
        #expect(cancelFake.callCount == 1)
        #expect(cancelFake.lastBookingID == myBooking.id)
        #expect(vm.myBookings.isEmpty)
        let presented = vm.presentedSlotsForSelectedDate
        let nineAMRow = try #require(presented.first { $0.slot.start == mondayNineAM })
        #expect(nineAMRow.state == .available)
    }

    // MARK: - Slice 1.5 — Owner view

    private func makeOwnerSUT(
        schedule: Schedule,
        ownerListResult: [OwnerBooking] = [],
        ownerListError: ListAllBookingsForOwnerError? = nil
    ) -> (
        vm: ScheduleCalendarViewModel,
        ownerListFake: FakeListAllBookingsForOwnerUseCase
    ) {
        let ownerListFake = FakeListAllBookingsForOwnerUseCase()
        ownerListFake.resultToReturn = ownerListResult
        ownerListFake.errorToThrow = ownerListError
        let vm = ScheduleCalendarViewModel(
            schedule: schedule,
            calendar: Self.utcCalendar,
            referenceDate: Self.date(year: 2026, month: 4, day: 1),
            isOwner: true,
            listAllBookingsForOwnerUseCase: ownerListFake
        )
        return (vm, ownerListFake)
    }

    // MARK: - BCV6

    @Test("BCV6. Owner 模式 onAppear 撈到 1 筆 OwnerBooking → 對應 slot 變 .bookedByStudent")
    func onAppear_ownerMode_oneBooking_slotIsBookedByStudent() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let monday = Self.date(year: 2026, month: 4, day: 13)
        let mondayTenAM = monday.addingTimeInterval(10 * 3600)
        let booking = try Self.booking(at: mondayTenAM, scheduleID: schedule.id)
        let ownerView = OwnerBooking(booking: booking, studentEmail: "test-student-c@example.com")
        let (vm, ownerListFake) = makeOwnerSUT(schedule: schedule, ownerListResult: [ownerView])

        // When
        await vm.onAppear()
        vm.selectDate(monday)

        // Then
        #expect(ownerListFake.callCount == 1)
        let presented = vm.presentedSlotsForSelectedDate
        let tenAMRow = try #require(presented.first { $0.slot.start == mondayTenAM })
        #expect(tenAMRow.state == .bookedByStudent(email: "test-student-c@example.com"))
        let others = presented.filter { $0.slot.start != mondayTenAM }
        #expect(others.allSatisfy { $0.state == .available })
    }

    // MARK: - BCV7

    @Test("BCV7. Owner 模式 listAllBookingsForOwner throws → 全部 slot 仍 .available（silent fail）")
    func onAppear_ownerMode_throws_fallsBackToAvailable() async throws {
        // Given
        let schedule = try makeScheduleWithMondayRule()
        let monday = Self.date(year: 2026, month: 4, day: 13)
        let (vm, ownerListFake) = makeOwnerSUT(schedule: schedule, ownerListError: .persistenceFailure)

        // When
        await vm.onAppear()
        vm.selectDate(monday)

        // Then
        #expect(ownerListFake.callCount == 1)
        #expect(vm.ownerBookings.isEmpty)
        let presented = vm.presentedSlotsForSelectedDate
        #expect(presented.allSatisfy { $0.state == .available })
    }
}

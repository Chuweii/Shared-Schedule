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
}

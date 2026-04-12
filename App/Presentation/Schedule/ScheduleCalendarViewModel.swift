import Foundation

@Observable
final class ScheduleCalendarViewModel {
    private(set) var schedule: Schedule
    private(set) var currentMonth: Date
    private(set) var days: [CalendarDay] = []
    private(set) var selectedDate: Date?
    private(set) var selectedDaySlots: [ComputedSlot] = []

    private let calendar: Calendar

    init(schedule: Schedule, calendar: Calendar = .current, referenceDate: Date = Date()) {
        self.schedule = schedule
        self.calendar = calendar
        self.currentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: referenceDate)
        ) ?? referenceDate
    }

    func onAppear() async {
        updateDays()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        selectedDaySlots = schedule.computedSlots(for: date, calendar: calendar)
    }

    func changeMonth(by delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: currentMonth) else { return }
        currentMonth = newMonth
        updateDays()
        selectedDate = nil
        selectedDaySlots = []
    }

    private func updateDays() {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            days = []
            return
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7
        let today = calendar.startOfDay(for: Date())

        var result: [CalendarDay] = []

        for offset in (-leadingPadding)..<(range.count) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) else { continue }
            let isCurrentMonth = offset >= 0
            let weekday = Weekday.from(date: date, calendar: calendar)
            let hasRule = !schedule.rulesFor(weekday: weekday).isEmpty
            let isToday = calendar.isDate(date, inSameDayAs: today)

            result.append(CalendarDay(
                date: date,
                isCurrentMonth: isCurrentMonth,
                hasRule: hasRule,
                isToday: isToday
            ))
        }

        let trailingCount = (7 - result.count % 7) % 7
        if let lastDate = result.last?.date {
            for i in 1...max(trailingCount, 1) {
                guard let date = calendar.date(byAdding: .day, value: i, to: lastDate) else { continue }
                if trailingCount == 0 { break }
                let weekday = Weekday.from(date: date, calendar: calendar)
                result.append(CalendarDay(
                    date: date,
                    isCurrentMonth: false,
                    hasRule: !schedule.rulesFor(weekday: weekday).isEmpty,
                    isToday: false
                ))
            }
        }

        days = result
    }
}

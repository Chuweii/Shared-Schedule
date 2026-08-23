import SwiftUI

struct CalendarGridView: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    let days: [CalendarDay]
    let selectedDate: Date?
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)

    /// Weekday headers follow the in-app language override, not the
    /// system locale.
    private var weekdayHeaders: [String] {
        var calendar = Calendar.current
        calendar.locale = locale
        return calendar.veryShortWeekdaySymbols
    }

    var body: some View {
        VStack(spacing: 8) {
            weekdayHeaderRow

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(days) { day in
                    let isSelected = selectedDate.map {
                        Calendar.current.isDate($0, inSameDayAs: day.date)
                    } ?? false

                    Button {
                        if day.isCurrentMonth {
                            onSelectDate(day.date)
                        }
                    } label: {
                        CalendarDayCell(day: day, isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .disabled(!day.isCurrentMonth)
                    // Read as one element: "今天，8月23日 星期六 / 有可預約時段".
                    // Leading-fill cells from adjacent months are dead
                    // targets — hide them instead of narrating them.
                    .accessibilityLabel(dayAccessibilityLabel(day))
                    .accessibilityValue(
                        day.hasRule && day.isCurrentMonth
                            ? Text("a11yDayHasSlots") : Text("a11yDayNoSlots")
                    )
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    .accessibilityHidden(!day.isCurrentMonth)
                }
            }
        }
        // Day cells clip at accessibility text sizes; capping the grid
        // (not the screen) is the standard calendar-grid mitigation.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private func dayAccessibilityLabel(_ day: CalendarDay) -> Text {
        let dateString = day.date.formatted(
            .dateTime.month().day().weekday(.wide).locale(locale)
        )
        guard day.isToday else { return Text(verbatim: dateString) }
        let today = String(localized: "a11yToday", bundle: .forLocale(locale))
        return Text(verbatim: "\(today)，\(dateString)")
    }

    private var weekdayHeaderRow: some View {
        HStack {
            ForEach(Array(weekdayHeaders.enumerated()), id: \.offset) { _, header in
                Text(verbatim: header)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.textCaption)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

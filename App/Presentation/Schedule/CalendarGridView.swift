import SwiftUI

struct CalendarGridView: View {
    @Environment(\.theme) private var theme
    let days: [CalendarDay]
    let selectedDate: Date?
    let onSelectDate: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    private var weekdayHeaders: [String] { Calendar.current.veryShortWeekdaySymbols }

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
                }
            }
        }
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

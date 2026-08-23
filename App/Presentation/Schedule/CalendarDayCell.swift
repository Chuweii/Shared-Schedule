import SwiftUI

struct CalendarDayCell: View {
    @Environment(\.theme) private var theme
    let day: CalendarDay
    let isSelected: Bool

    var body: some View {
        let calendar = Calendar.current
        let dayNumber = calendar.component(.day, from: day.date)

        ZStack {
            if isSelected {
                Circle()
                    .fill(theme.buttonBgPrimary)
            } else if day.isToday {
                Circle()
                    .stroke(theme.system, lineWidth: 1.5)
            }

            VStack(spacing: 2) {
                Text("\(dayNumber)")
                    .font(.subheadline.weight(day.isToday ? .bold : .regular))
                    .foregroundStyle(textColor)

                if day.hasRule && day.isCurrentMonth {
                    Circle()
                        .fill(isSelected ? theme.buttonTextPrimary : theme.system)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(.clear)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(minHeight: 44)
    }

    private var textColor: Color {
        if isSelected {
            return theme.buttonTextPrimary
        }
        if !day.isCurrentMonth {
            return theme.textDisable
        }
        if !day.hasRule {
            return theme.textCaption
        }
        return theme.textPrimary
    }
}

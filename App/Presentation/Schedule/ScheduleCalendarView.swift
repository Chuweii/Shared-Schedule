import SwiftUI

struct ScheduleCalendarView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel: ScheduleCalendarViewModel

    init(schedule: Schedule) {
        self.viewModel = ScheduleCalendarViewModel(schedule: schedule)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthHeader
                CalendarGridView(
                    days: viewModel.days,
                    selectedDate: viewModel.selectedDate,
                    onSelectDate: { viewModel.selectDate($0) }
                )
                .padding(.horizontal)

                if let selectedDate = viewModel.selectedDate {
                    Divider()
                        .padding(.horizontal)

                    selectedDateHeader(selectedDate)

                    DaySlotListView(
                        date: selectedDate,
                        slots: viewModel.selectedDaySlots
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
        }
        .navigationTitle(viewModel.schedule.title)
        .task { await viewModel.onAppear() }
    }

    private var monthHeader: some View {
        HStack {
            Button { viewModel.changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.medium))
            }

            Spacer()

            Text(monthYearString)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button { viewModel.changeMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.weight(.medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private func selectedDateHeader(_ date: Date) -> some View {
        Text(date, style: .date)
            .font(.headline)
            .foregroundStyle(theme.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
    }

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy 年 M 月"
        return formatter.string(from: viewModel.currentMonth)
    }
}

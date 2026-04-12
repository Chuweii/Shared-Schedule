import SwiftUI

struct CreateScheduleSheet: View {
    @Environment(\.theme) private var theme
    @Bindable var viewModel: ScheduleListViewModel

    private let durationOptions: [TimeInterval] = [
        900, 1800, 2700, 3600, 5400, 7200
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("輸入課表名稱", text: $viewModel.titleDraft)

                    if let error = viewModel.inlineError {
                        Label(errorMessage(for: error), systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(theme.error)
                    }
                }

                Section("最短時段長度") {
                    Picker("最短時段長度", selection: $viewModel.minDurationDraft) {
                        ForEach(durationOptions, id: \.self) { duration in
                            Text("\(Int(duration / 60)) 分鐘").tag(duration)
                        }
                    }
                }

                Section {
                    weekdayPicker
                } header: {
                    Text("可預約日期")
                } footer: {
                    Text("建立後可針對每天細調時段")
                        .font(.caption2)
                }

                if !viewModel.selectedWeekdays.isEmpty {
                    Section("可預約時間") {
                        DatePicker(
                            "開始",
                            selection: $viewModel.ruleStartTime,
                            displayedComponents: .hourAndMinute
                        )
                        DatePicker(
                            "結束",
                            selection: $viewModel.ruleEndTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }
            }
            .navigationTitle("新增課表")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.didCancelCreate()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("建立") {
                        Task { await viewModel.didConfirmCreate() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var weekdayPicker: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                weekdayChip(weekday)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func weekdayChip(_ weekday: Weekday) -> some View {
        let isSelected = viewModel.selectedWeekdays.contains(weekday)
        return Button {
            if isSelected {
                viewModel.selectedWeekdays.remove(weekday)
            } else {
                viewModel.selectedWeekdays.insert(weekday)
            }
        } label: {
            Text(weekdayShortName(weekday))
                .font(.caption.weight(.medium))
                .frame(width: 36, height: 36)
                .foregroundStyle(isSelected ? theme.buttonTextPrimary : theme.textSecondary)
                .background(isSelected ? theme.buttonBgPrimary : theme.bgSecondary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var orderedWeekdays: [Weekday] {
        [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    }

    private func weekdayShortName(_ weekday: Weekday) -> LocalizedStringKey {
        switch weekday {
        case .monday: "一"
        case .tuesday: "二"
        case .wednesday: "三"
        case .thursday: "四"
        case .friday: "五"
        case .saturday: "六"
        case .sunday: "日"
        }
    }

    private func errorMessage(for error: CreateScheduleError) -> LocalizedStringKey {
        switch error {
        case .blankTitle: "標題不能為空"
        }
    }
}

#Preview {
    CreateScheduleSheet(
        viewModel: ScheduleListViewModel(
            createScheduleUseCase: CreateScheduleUseCase(
                repository: InMemoryScheduleRepository(),
                currentUserProvider: InMemoryCurrentUserProvider()
            ),
            listSchedulesUseCase: ListSchedulesUseCase(
                repository: InMemoryScheduleRepository(),
                currentUserProvider: InMemoryCurrentUserProvider()
            )
        )
    )
    .environment(\.theme, ClassicTheme())
}

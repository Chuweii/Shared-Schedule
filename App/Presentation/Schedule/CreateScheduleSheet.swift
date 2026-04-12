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

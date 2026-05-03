import SwiftUI

struct AddWindowSheet: View {
    @Environment(\.theme) private var theme
    @Bindable var viewModel: ScheduleDetailViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("開始時間") {
                    DatePicker(
                        "開始",
                        selection: $viewModel.newWindowStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                Section("結束時間") {
                    DatePicker(
                        "結束",
                        selection: $viewModel.newWindowEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }

                if let error = viewModel.inlineError {
                    Section {
                        Label(errorMessage(for: error), systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(theme.error)
                    }
                }
            }
            .navigationTitle("新增時段")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.didCancelAddWindow()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("新增") {
                        Task { await viewModel.didConfirmAddWindow() }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func errorMessage(for error: ScheduleMutationError) -> LocalizedStringKey {
        switch error {
        case .scheduleError(.overlapping):
            "時段與既有時段重疊"
        case .scheduleError(.belowMinimumDuration):
            "時段長度不得短於最短時段設定"
        case .scheduleError(.invalidRange):
            "結束時間必須晚於開始時間"
        case .scheduleError(.ruleOverlapping):
            "該日已有可預約規則"
        case .scheduleError(.ruleTooShort):
            "規則時段不得短於最短時段設定"
        case .notOwner:
            "無權限修改此課表"
        case .scheduleNotFound:
            "找不到此課表"
        case .repositoryFailure:
            "儲存失敗，請稍後再試"
        }
    }
}

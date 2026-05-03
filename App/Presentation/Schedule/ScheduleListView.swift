import SwiftUI

struct ScheduleListView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel: ScheduleListViewModel
    @State private var showSettings = false
    @State private var showRedeemSheet = false
    @State private var pendingSignOut = false
    private let dependencies: AppDependencies
    private let onSignOut: (() async -> Void)?

    init(dependencies: AppDependencies, onSignOut: (() async -> Void)? = nil) {
        self.dependencies = dependencies
        self.onSignOut = onSignOut
        self.viewModel = ScheduleListViewModel(
            createScheduleUseCase: dependencies.createScheduleUseCase,
            listSchedulesUseCase: dependencies.listSchedulesUseCase
        )
    }

    var body: some View {
        Group {
            if let error = viewModel.loadError {
                errorStateView(message: error)
            } else if viewModel.schedules.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .navigationTitle("我的課表")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showRedeemSheet = true } label: {
                    Image(systemName: "envelope.badge")
                }
                .accessibilityLabel(Text("輸入邀請碼"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.isCreateSheetPresented = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreateSheetPresented) {
            CreateScheduleSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showRedeemSheet) {
            RedeemInvitationSheet(viewModel: RedeemInvitationViewModel(
                redeemInvitationUseCase: dependencies.redeemInvitationUseCase
            ))
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                ThemeSettingsView(onSignOut: {
                    showSettings = false
                    pendingSignOut = true
                })
                    .navigationTitle("設定")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showSettings = false }
                        }
                    }
            }
            .environment(themeManager)
        }
        .task { await viewModel.onAppear() }
        .onChange(of: pendingSignOut) {
            guard pendingSignOut else { return }
            pendingSignOut = false
            Task { await onSignOut?() }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("還沒有課表", systemImage: "calendar.badge.plus")
        } description: {
            Text("建立你的第一份課表，讓學生預約你的時間")
        } actions: {
            VStack(spacing: 12) {
                Button {
                    viewModel.isCreateSheetPresented = true
                } label: {
                    Text("建立課表")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.buttonTextPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(theme.buttonBgPrimary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    showRedeemSheet = true
                } label: {
                    Text("輸入邀請碼")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.textSecondary)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func errorStateView(message: LocalizedStringResource) -> some View {
        ContentUnavailableView {
            Label(String(localized: message), systemImage: "exclamationmark.triangle")
        } actions: {
            Button {
                Task { await viewModel.retry() }
            } label: {
                Text("重試")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.buttonTextPrimary)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(theme.buttonBgPrimary)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var listView: some View {
        List(viewModel.schedules, id: \.id) { schedule in
            NavigationLink {
                ScheduleCalendarView(schedule: schedule, dependencies: dependencies)
            } label: {
                scheduleRow(schedule)
            }
        }
    }

    private func scheduleRow(_ schedule: Schedule) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(schedule.title)
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            if schedule.rules.isEmpty {
                Text("每堂最短 \(Int(schedule.minWindowDuration / 60)) 分鐘")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Text(ruleSummary(schedule))
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func ruleSummary(_ schedule: Schedule) -> String {
        let symbols = Calendar.current.shortWeekdaySymbols
        let weekdayNames = schedule.rules
            .sorted { $0.weekday.rawValue < $1.weekday.rawValue }
            .map { symbols[$0.weekday.rawValue - 1] }
            .joined(separator: ", ")

        if let first = schedule.rules.first {
            let start = String(format: "%02d:%02d", first.startTime.hour, first.startTime.minute)
            let end = String(format: "%02d:%02d", first.endTime.hour, first.endTime.minute)
            return "\(weekdayNames)  \(start) — \(end)"
        }
        return weekdayNames
    }
}

#Preview {
    NavigationStack {
        ScheduleListView(dependencies: .live)
    }
    .environment(\.theme, ClassicTheme())
    .environment(ThemeManager())
}

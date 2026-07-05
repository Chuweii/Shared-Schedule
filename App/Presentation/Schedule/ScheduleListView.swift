import SwiftUI

struct ScheduleListView: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @Environment(ThemeManager.self) private var themeManager
    @Environment(LanguageManager.self) private var languageManager
    @State private var viewModel: ScheduleListViewModel
    @State private var showSettings = false
    @State private var showRedeemSheet = false
    @State private var pendingSignOut = false
    @State private var pendingAccountDeleted = false
    private let dependencies: AppDependencies
    private let onSignOut: (() async -> Void)?
    private let onAccountDeleted: (() async -> Void)?

    init(
        dependencies: AppDependencies,
        onSignOut: (() async -> Void)? = nil,
        onAccountDeleted: (() async -> Void)? = nil
    ) {
        self.dependencies = dependencies
        self.onSignOut = onSignOut
        self.onAccountDeleted = onAccountDeleted
        self.viewModel = ScheduleListViewModel(
            createScheduleUseCase: dependencies.createScheduleUseCase,
            listSchedulesUseCase: dependencies.listSchedulesUseCase,
            listJoinedSchedulesUseCase: dependencies.listJoinedSchedulesUseCase
        )
    }

    var body: some View {
        Group {
            if viewModel.isFullScreenError {
                fullScreenErrorView
            } else if viewModel.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        // Resolved as String (not LocalizedStringKey) so the bar title
        // re-pushes when the in-app language changes — the bar only
        // refreshes on value change, and a key compares equal across
        // locale switches.
        .navigationTitle(String(localized: "課表", bundle: .forLocale(locale)))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        viewModel.isCreateSheetPresented = true
                    } label: {
                        Label("建立課表", systemImage: "calendar.badge.plus")
                    }
                    Button {
                        showRedeemSheet = true
                    } label: {
                        Label("加入別人的課表", systemImage: "envelope.badge")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreateSheetPresented) {
            CreateScheduleSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showRedeemSheet, onDismiss: {
            Task { await viewModel.onAppear() }
        }) {
            RedeemInvitationSheet(viewModel: RedeemInvitationViewModel(
                redeemInvitationUseCase: dependencies.redeemInvitationUseCase
            ))
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(
                    dependencies: dependencies,
                    onSignOut: {
                        showSettings = false
                        pendingSignOut = true
                    },
                    onAccountDeleted: {
                        showSettings = false
                        pendingAccountDeleted = true
                    }
                )
                .navigationTitle(String(localized: "設定", bundle: .forLocale(locale)))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完成") { showSettings = false }
                    }
                }
            }
            .environment(themeManager)
            .environment(languageManager)
        }
        .task { await viewModel.onAppear() }
        .onChange(of: pendingSignOut) {
            guard pendingSignOut else { return }
            pendingSignOut = false
            Task { await onSignOut?() }
        }
        .onChange(of: pendingAccountDeleted) {
            guard pendingAccountDeleted else { return }
            pendingAccountDeleted = false
            Task { await onAccountDeleted?() }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("還沒有課表", systemImage: "calendar.badge.plus")
        } description: {
            Text("建立自己的課表，或輸入邀請碼加入別人的")
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

    private var fullScreenErrorView: some View {
        ContentUnavailableView {
            Label("scheduleListLoadError", systemImage: "exclamationmark.triangle")
        } actions: {
            Button {
                Task { await viewModel.onAppear() }
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
        List {
            if !viewModel.ownedSchedules.isEmpty || viewModel.ownedLoadError != nil {
                Section("我的課表") {
                    if let err = viewModel.ownedLoadError {
                        inlineRetryRow(message: err) {
                            await viewModel.retryOwned()
                        }
                    } else {
                        ForEach(viewModel.ownedSchedules, id: \.id) { schedule in
                            scheduleNavigationRow(schedule)
                        }
                    }
                }
            }
            if !viewModel.joinedSchedules.isEmpty || viewModel.joinedLoadError != nil {
                Section("我加入的") {
                    if let err = viewModel.joinedLoadError {
                        inlineRetryRow(message: err) {
                            await viewModel.retryJoined()
                        }
                    } else {
                        ForEach(viewModel.joinedSchedules, id: \.id) { schedule in
                            scheduleNavigationRow(schedule)
                        }
                    }
                }
            }
        }
        .refreshable { await viewModel.onAppear() }
    }

    private func scheduleNavigationRow(_ schedule: Schedule) -> some View {
        NavigationLink {
            ScheduleCalendarView(schedule: schedule, dependencies: dependencies)
        } label: {
            scheduleRow(schedule)
        }
    }

    private func inlineRetryRow(message: LocalizedStringResource, retry: @escaping () async -> Void) -> some View {
        HStack {
            Text(message)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Spacer()
            Button {
                Task { await retry() }
            } label: {
                Text("重試")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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
        // Weekday names follow the in-app language override, not the
        // system locale.
        var calendar = Calendar.current
        calendar.locale = locale
        let symbols = calendar.shortWeekdaySymbols
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
    .environment(LanguageManager())
}

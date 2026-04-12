import SwiftUI

struct ScheduleListView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel: ScheduleListViewModel
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        self.viewModel = ScheduleListViewModel(
            createScheduleUseCase: dependencies.createScheduleUseCase,
            listSchedulesUseCase: dependencies.listSchedulesUseCase
        )
    }

    var body: some View {
        Group {
            if viewModel.schedules.isEmpty {
                emptyStateView
            } else {
                listView
            }
        }
        .navigationTitle("我的課表")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.isCreateSheetPresented = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $viewModel.isCreateSheetPresented) {
            CreateScheduleSheet(viewModel: viewModel)
        }
        .task { await viewModel.onAppear() }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("還沒有課表", systemImage: "calendar.badge.plus")
        } description: {
            Text("建立你的第一份課表，讓學生預約你的時間")
        } actions: {
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
        }
    }

    private var listView: some View {
        List(viewModel.schedules, id: \.id) { schedule in
            NavigationLink {
                ScheduleDetailView(schedule: schedule, dependencies: dependencies)
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

            Text("每堂最短 \(Int(schedule.minWindowDuration / 60)) 分鐘")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ScheduleListView(dependencies: .live)
    }
    .environment(\.theme, ClassicTheme())
    .environment(ThemeManager())
}

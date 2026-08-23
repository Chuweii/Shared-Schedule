import SwiftUI

struct ScheduleDetailView: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale
    @State private var viewModel: ScheduleDetailViewModel

    init(schedule: Schedule, dependencies: AppDependencies) {
        self.viewModel = ScheduleDetailViewModel(
            schedule: schedule,
            addWindowUseCase: AddAvailabilityWindowUseCase(
                repository: dependencies.repository,
                currentUserProvider: dependencies.currentUserProvider
            ),
            removeWindowUseCase: RemoveAvailabilityWindowUseCase(
                repository: dependencies.repository,
                currentUserProvider: dependencies.currentUserProvider
            )
        )
    }

    var body: some View {
        Group {
            if viewModel.schedule.windows.isEmpty {
                emptyStateView
            } else {
                windowListView
            }
        }
        .navigationTitle(viewModel.schedule.title)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { viewModel.isAddWindowSheetPresented = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("a11yAddWindow"))
            }
        }
        .sheet(isPresented: $viewModel.isAddWindowSheetPresented) {
            AddWindowSheet(viewModel: viewModel)
        }
        .task { await viewModel.onAppear() }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("還沒有時段", systemImage: "clock.badge.plus")
        } description: {
            Text("新增可預約時段，讓學生知道你何時有空")
        } actions: {
            Button {
                viewModel.isAddWindowSheetPresented = true
            } label: {
                Text("新增時段")
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

    private var windowListView: some View {
        List {
            Section {
                ForEach(viewModel.schedule.windows, id: \.id) { window in
                    windowRow(window)
                }
                .onDelete { indexSet in
                    guard let index = indexSet.first else { return }
                    let windowID = viewModel.schedule.windows[index].id
                    Task { await viewModel.didTapDelete(windowID: windowID) }
                }
            } header: {
                Text("每堂最短 \(Int(viewModel.schedule.minWindowDuration / 60)) 分鐘")
                    .font(.caption)
            }
        }
    }

    private func windowRow(_ window: AvailabilityWindow) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(window.start, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)

                HStack(spacing: 4) {
                    Text(window.start, style: .time)
                    Text("—")
                    Text(window.end, style: .time)
                }
                .font(.headline)
                .foregroundStyle(theme.textPrimary)
            }

            Spacer()

            Text("\(Int(window.duration / 60)) 分鐘")
                .font(.caption)
                .foregroundStyle(theme.textCaption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.bgSecondary)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: windowAccessibilityLabel(window)))
    }

    private func windowAccessibilityLabel(_ window: AvailabilityWindow) -> String {
        let bundle = Bundle.forLocale(locale)
        let date = window.start.formatted(.dateTime.year().month().day().locale(locale))
        let range = String(
            localized: "a11ySlotTimeRange \(window.start.formatted(.dateTime.hour().minute().locale(locale))) \(window.end.formatted(.dateTime.hour().minute().locale(locale)))",
            bundle: bundle
        )
        let duration = String(localized: "\(Int(window.duration / 60)) 分鐘", bundle: bundle)
        return "\(date)，\(range)，\(duration)"
    }
}

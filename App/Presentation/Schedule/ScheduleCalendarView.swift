import SwiftUI

struct ScheduleCalendarView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel: ScheduleCalendarViewModel
    @State private var showInviteSheet = false
    @State private var pendingSlot: ComputedSlot?
    @State private var pendingCancelBookingID: BookingID?
    private let dependencies: AppDependencies?

    init(schedule: Schedule, dependencies: AppDependencies? = nil) {
        self.dependencies = dependencies
        let isOwner: Bool = {
            guard let dependencies else { return false }
            return schedule.ownerID == dependencies.currentUserProvider.currentUser.id
        }()
        self.viewModel = ScheduleCalendarViewModel(
            schedule: schedule,
            isOwner: isOwner,
            listMyBookingsUseCase: dependencies?.listMyBookingsUseCase,
            createBookingUseCase: dependencies?.createBookingUseCase,
            cancelBookingUseCase: dependencies?.cancelBookingUseCase,
            listAllBookingsForOwnerUseCase: dependencies?.listAllBookingsForOwnerUseCase,
            listOthersBookingsUseCase: dependencies?.listOthersBookingsUseCase
        )
    }

    private var isOwner: Bool {
        guard let dependencies else { return false }
        return viewModel.schedule.ownerID == dependencies.currentUserProvider.currentUser.id
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

                    if let inlineError = viewModel.inlineError {
                        Text(inlineError)
                            .font(.subheadline)
                            .foregroundStyle(theme.textCaption)
                            .padding(.horizontal)
                    }

                    DaySlotListView(
                        date: selectedDate,
                        presentedSlots: viewModel.presentedSlotsForSelectedDate,
                        interactive: !isOwner,
                        onTapAvailable: { pendingSlot = $0 },
                        onTapCancel: { pendingCancelBookingID = $0 }
                    )
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
        }
        .navigationTitle(viewModel.schedule.title)
        .toolbar {
            if isOwner {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showInviteSheet = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                    }
                    .accessibilityLabel(Text("邀請學生"))
                }
            }
        }
        .sheet(isPresented: $showInviteSheet) {
            if let dependencies {
                InviteSheet(viewModel: InviteSheetViewModel(
                    schedule: viewModel.schedule,
                    createInvitationUseCase: dependencies.createInvitationUseCase,
                    listInvitationsUseCase: dependencies.listInvitationsUseCase
                ))
            }
        }
        .alert(
            confirmationTitle,
            isPresented: bookingConfirmationBinding
        ) {
            Button("預約這個時段") {
                if let pendingSlot {
                    Task { await viewModel.bookSlot(pendingSlot) }
                }
                pendingSlot = nil
            }
            Button("取消", role: .cancel) {
                pendingSlot = nil
            }
        }
        .alert(
            "確定取消這筆預約？",
            isPresented: cancelConfirmationBinding
        ) {
            Button("取消預約", role: .destructive) {
                if let pendingCancelBookingID {
                    Task { await viewModel.cancelBooking(pendingCancelBookingID) }
                }
                pendingCancelBookingID = nil
            }
            Button("取消", role: .cancel) {
                pendingCancelBookingID = nil
            }
        }
        .task { await viewModel.onAppear() }
    }

    /// `Text` (LocalizedStringKey interpolation) so the title follows
    /// the in-app language override — `LocalizedStringResource` would
    /// resolve against the system language.
    private var confirmationTitle: Text {
        if let pendingSlot {
            let startStr = Self.timeFormatter.string(from: pendingSlot.start)
            let endStr = Self.timeFormatter.string(from: pendingSlot.end)
            return Text("確定預約 \(startStr)–\(endStr)？")
        }
        return Text("確定預約？")
    }

    /// 24-hour HH:mm — matches DaySlotListView so confirmation title
    /// reads identically to the row that triggered it.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var bookingConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingSlot != nil },
            set: { if !$0 { pendingSlot = nil } }
        )
    }

    private var cancelConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingCancelBookingID != nil },
            set: { if !$0 { pendingCancelBookingID = nil } }
        )
    }

    private var monthHeader: some View {
        HStack {
            Button { viewModel.changeMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.medium))
            }

            Spacer()

            Text(viewModel.currentMonth, format: .dateTime.year().month(.wide))
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

}

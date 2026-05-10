import Foundation

@MainActor
@Observable
final class ScheduleCalendarViewModel {
    private(set) var schedule: Schedule
    private(set) var currentMonth: Date
    private(set) var days: [CalendarDay] = []
    private(set) var selectedDate: Date?
    private(set) var selectedDaySlots: [ComputedSlot] = []
    private(set) var myBookings: [Booking] = []
    private(set) var ownerBookings: [OwnerBooking] = []
    private(set) var othersBookings: [BookedSlot] = []
    private(set) var inlineError: LocalizedStringResource?

    private let calendar: Calendar
    private let isOwner: Bool
    private let listMyBookingsUseCase: (any ListMyBookingsUseCaseProtocol)?
    private let createBookingUseCase: (any CreateBookingUseCaseProtocol)?
    private let cancelBookingUseCase: (any CancelBookingUseCaseProtocol)?
    private let listAllBookingsForOwnerUseCase: (any ListAllBookingsForOwnerUseCaseProtocol)?
    private let listOthersBookingsUseCase: (any ListOthersBookingsUseCaseProtocol)?

    init(
        schedule: Schedule,
        calendar: Calendar = .current,
        referenceDate: Date = Date(),
        isOwner: Bool = false,
        listMyBookingsUseCase: (any ListMyBookingsUseCaseProtocol)? = nil,
        createBookingUseCase: (any CreateBookingUseCaseProtocol)? = nil,
        cancelBookingUseCase: (any CancelBookingUseCaseProtocol)? = nil,
        listAllBookingsForOwnerUseCase: (any ListAllBookingsForOwnerUseCaseProtocol)? = nil,
        listOthersBookingsUseCase: (any ListOthersBookingsUseCaseProtocol)? = nil
    ) {
        self.schedule = schedule
        self.calendar = calendar
        self.currentMonth = calendar.date(
            from: calendar.dateComponents([.year, .month], from: referenceDate)
        ) ?? referenceDate
        self.isOwner = isOwner
        self.listMyBookingsUseCase = listMyBookingsUseCase
        self.createBookingUseCase = createBookingUseCase
        self.cancelBookingUseCase = cancelBookingUseCase
        self.listAllBookingsForOwnerUseCase = listAllBookingsForOwnerUseCase
        self.listOthersBookingsUseCase = listOthersBookingsUseCase
    }

    var presentedSlotsForSelectedDate: [PresentedSlot] {
        selectedDaySlots.map { slot in
            let state: SlotPresentationState
            if isOwner {
                if let owned = ownerBookings.first(where: { $0.booking.matches(slot) }) {
                    state = .bookedByStudent(
                        displayName: owned.studentDisplayName,
                        email: owned.studentEmail
                    )
                } else {
                    state = .available
                }
            } else if let booking = myBookings.first(where: { $0.matches(slot) }) {
                // mineBooked beats bookedByOther — race / inconsistent
                // state should preserve the cancel affordance.
                state = .mineBooked(booking.id)
            } else if othersBookings.contains(where: { $0.matches(slot) }) {
                state = .bookedByOther
            } else {
                state = .available
            }
            return PresentedSlot(
                id: "\(slot.start.timeIntervalSince1970)",
                slot: slot,
                state: state
            )
        }
    }

    func onAppear() async {
        updateDays()
        await loadBookings()
    }

    func selectDate(_ date: Date) {
        selectedDate = date
        selectedDaySlots = schedule.computedSlots(for: date, calendar: calendar)
    }

    func changeMonth(by delta: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: delta, to: currentMonth) else { return }
        currentMonth = newMonth
        updateDays()
        selectedDate = nil
        selectedDaySlots = []
    }

    func loadBookings() async {
        if isOwner {
            await loadOwnerBookings()
        } else {
            await loadMyBookings()
            await loadOthersBookings()
        }
    }

    private func loadMyBookings() async {
        guard let listMyBookingsUseCase else { return }
        do {
            myBookings = try await listMyBookingsUseCase.listMyBookings(scheduleID: schedule.id)
        } catch {
            // Calendar still renders without my-bookings overlay; user can
            // re-enter the view to retry. We deliberately don't surface to
            // inlineError here so the slot-list area isn't hijacked on entry.
        }
    }

    private func loadOwnerBookings() async {
        guard let listAllBookingsForOwnerUseCase else { return }
        do {
            ownerBookings = try await listAllBookingsForOwnerUseCase.listAllBookingsForOwner(
                scheduleID: schedule.id
            )
        } catch {
            // Same silent-on-load policy as loadMyBookings.
        }
    }

    private func loadOthersBookings() async {
        guard let listOthersBookingsUseCase else { return }
        do {
            othersBookings = try await listOthersBookingsUseCase.listOthersBookings(
                scheduleID: schedule.id
            )
        } catch {
            // Same silent-on-load policy as loadMyBookings — rows fall
            // back to .available rather than blocking the slot list.
        }
    }

    func bookSlot(_ slot: ComputedSlot) async {
        guard let createBookingUseCase else { return }
        inlineError = nil
        do {
            let booking = try await createBookingUseCase.createBooking(
                scheduleID: schedule.id,
                slot: slot
            )
            myBookings.append(booking)
        } catch {
            inlineError = Self.errorMessage(for: error)
        }
    }

    func cancelBooking(_ id: BookingID) async {
        guard let cancelBookingUseCase else { return }
        inlineError = nil
        do {
            try await cancelBookingUseCase.cancelBooking(id)
            myBookings.removeAll { $0.id == id }
        } catch {
            inlineError = Self.errorMessage(for: error)
        }
    }

    private static func errorMessage(for error: CreateBookingError) -> LocalizedStringResource {
        switch error {
        case .slotTaken: return "已被預約，請選其他時段"
        case .slotInPast: return "這個時段已過"
        case .slotNotInSchedule: return "這個時段不在課表內"
        case .ownerCannotBook: return "老師不能預約自己的課表"
        case .notMember: return "你還不是這個課表的學生"
        case .scheduleNotFound, .persistenceFailure: return "預約失敗，請稍後再試"
        }
    }

    private static func errorMessage(for error: CancelBookingError) -> LocalizedStringResource {
        switch error {
        case .slotAlreadyStarted: return "這個時段已開始，無法取消"
        case .notOwner, .bookingNotFound, .persistenceFailure: return "預約失敗，請稍後再試"
        }
    }

    private func updateDays() {
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            days = []
            return
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingPadding = (firstWeekday - calendar.firstWeekday + 7) % 7
        let today = calendar.startOfDay(for: Date())

        var result: [CalendarDay] = []

        for offset in (-leadingPadding)..<(range.count) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstOfMonth) else { continue }
            let isCurrentMonth = offset >= 0
            let weekday = Weekday.from(date: date, calendar: calendar)
            let hasRule = !schedule.rulesFor(weekday: weekday).isEmpty
            let isToday = calendar.isDate(date, inSameDayAs: today)

            result.append(CalendarDay(
                date: date,
                isCurrentMonth: isCurrentMonth,
                hasRule: hasRule,
                isToday: isToday
            ))
        }

        let trailingCount = (7 - result.count % 7) % 7
        if let lastDate = result.last?.date {
            for i in 1...max(trailingCount, 1) {
                guard let date = calendar.date(byAdding: .day, value: i, to: lastDate) else { continue }
                if trailingCount == 0 { break }
                let weekday = Weekday.from(date: date, calendar: calendar)
                result.append(CalendarDay(
                    date: date,
                    isCurrentMonth: false,
                    hasRule: !schedule.rulesFor(weekday: weekday).isEmpty,
                    isToday: false
                ))
            }
        }

        days = result
    }
}

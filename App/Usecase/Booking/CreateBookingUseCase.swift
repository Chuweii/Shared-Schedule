import Foundation

nonisolated struct CreateBookingUseCase: CreateBookingUseCaseProtocol {
    let scheduleRepository: any ScheduleRepositoryProtocol
    let bookingRepository: any BookingRepositoryProtocol
    let currentUserProvider: any CurrentUserProviderProtocol
    let calendar: Calendar
    let now: @Sendable () -> Date

    init(
        scheduleRepository: any ScheduleRepositoryProtocol,
        bookingRepository: any BookingRepositoryProtocol,
        currentUserProvider: any CurrentUserProviderProtocol,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.scheduleRepository = scheduleRepository
        self.bookingRepository = bookingRepository
        self.currentUserProvider = currentUserProvider
        self.calendar = calendar
        self.now = now
    }

    func createBooking(scheduleID: ScheduleID, slot: ComputedSlot)
        async throws(CreateBookingError) -> Booking
    {
        let scheduleOpt: Schedule?
        do {
            scheduleOpt = try await scheduleRepository.fetch(id: scheduleID)
        } catch {
            throw .persistenceFailure
        }

        guard let schedule = scheduleOpt else { throw .scheduleNotFound }

        if schedule.ownerID == currentUserProvider.currentUser.id {
            throw .ownerCannotBook
        }

        if slot.start <= now() {
            throw .slotInPast
        }

        let validSlots = schedule.computedSlots(for: slot.start, calendar: calendar)
        guard validSlots.contains(slot) else {
            throw .slotNotInSchedule
        }

        let durationSeconds = Int(slot.end.timeIntervalSince(slot.start).rounded())
        return try await bookingRepository.create(
            scheduleID: scheduleID,
            startsAt: slot.start,
            endsAt: slot.end,
            durationSeconds: durationSeconds
        )
    }
}

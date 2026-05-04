import Foundation

@Observable
@MainActor
final class ScheduleListViewModel {
    private(set) var ownedSchedules: [Schedule] = []
    private(set) var joinedSchedules: [Schedule] = []
    private(set) var ownedLoadError: LocalizedStringResource?
    private(set) var joinedLoadError: LocalizedStringResource?
    private(set) var inlineError: CreateScheduleError?
    var isCreateSheetPresented = false
    var titleDraft = ""
    var minDurationDraft: TimeInterval = Schedule.defaultMinWindowDuration
    var selectedWeekdays: Set<Weekday> = []
    var ruleStartTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var ruleEndTime: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()

    var isFullScreenError: Bool {
        ownedLoadError != nil
            && joinedLoadError != nil
            && ownedSchedules.isEmpty
            && joinedSchedules.isEmpty
    }

    var isEmpty: Bool {
        ownedSchedules.isEmpty
            && joinedSchedules.isEmpty
            && ownedLoadError == nil
            && joinedLoadError == nil
    }

    private struct LoadResult {
        let schedules: [Schedule]
        let error: LocalizedStringResource?
    }

    private let createScheduleUseCase: any CreateScheduleUseCaseProtocol
    private let listSchedulesUseCase: any ListSchedulesUseCaseProtocol
    private let listJoinedSchedulesUseCase: any ListJoinedSchedulesUseCaseProtocol

    init(
        createScheduleUseCase: any CreateScheduleUseCaseProtocol,
        listSchedulesUseCase: any ListSchedulesUseCaseProtocol,
        listJoinedSchedulesUseCase: any ListJoinedSchedulesUseCaseProtocol
    ) {
        self.createScheduleUseCase = createScheduleUseCase
        self.listSchedulesUseCase = listSchedulesUseCase
        self.listJoinedSchedulesUseCase = listJoinedSchedulesUseCase
    }

    func onAppear() async {
        async let owned = fetchOwnedResult()
        async let joined = fetchJoinedResult()
        let (o, j) = await (owned, joined)
        ownedSchedules = o.schedules
        ownedLoadError = o.error
        joinedSchedules = j.schedules
        joinedLoadError = j.error
    }

    func retryOwned() async {
        let result = await fetchOwnedResult()
        ownedSchedules = result.schedules
        ownedLoadError = result.error
    }

    func retryJoined() async {
        let result = await fetchJoinedResult()
        joinedSchedules = result.schedules
        joinedLoadError = result.error
    }

    private func fetchOwnedResult() async -> LoadResult {
        do {
            let schedules = try await listSchedulesUseCase.listSchedules()
            return LoadResult(schedules: schedules, error: nil)
        } catch {
            return LoadResult(schedules: [], error: "scheduleListLoadError")
        }
    }

    private func fetchJoinedResult() async -> LoadResult {
        do {
            let schedules = try await listJoinedSchedulesUseCase.listJoinedSchedules()
            return LoadResult(schedules: schedules, error: nil)
        } catch {
            return LoadResult(schedules: [], error: "scheduleListJoinedLoadError")
        }
    }

    func didCancelCreate() {
        isCreateSheetPresented = false
        inlineError = nil
        resetCreateForm()
    }

    func didConfirmCreate() async {
        let template: AvailabilityRuleTemplate?
        if selectedWeekdays.isEmpty {
            template = nil
        } else {
            let calendar = Calendar.current
            let startHour = calendar.component(.hour, from: ruleStartTime)
            let startMinute = calendar.component(.minute, from: ruleStartTime)
            let endHour = calendar.component(.hour, from: ruleEndTime)
            let endMinute = calendar.component(.minute, from: ruleEndTime)

            guard let start = try? TimeOfDay(hour: startHour, minute: startMinute),
                  let end = try? TimeOfDay(hour: endHour, minute: endMinute) else {
                return
            }

            template = AvailabilityRuleTemplate(
                weekdays: selectedWeekdays,
                startTime: start,
                endTime: end
            )
        }

        do {
            let newSchedule = try await createScheduleUseCase.createSchedule(
                title: titleDraft,
                minWindowDuration: minDurationDraft,
                ruleTemplate: template
            )
            ownedSchedules.append(newSchedule)
            isCreateSheetPresented = false
            inlineError = nil
            resetCreateForm()
        } catch {
            inlineError = error
        }
    }

    private func resetCreateForm() {
        titleDraft = ""
        minDurationDraft = Schedule.defaultMinWindowDuration
        selectedWeekdays = []
        ruleStartTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
        ruleEndTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

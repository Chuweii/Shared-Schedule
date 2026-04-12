import Foundation

@Observable
final class ScheduleListViewModel {
    private(set) var schedules: [Schedule] = []
    private(set) var inlineError: CreateScheduleError?
    var isCreateSheetPresented = false
    var titleDraft = ""
    var minDurationDraft: TimeInterval = Schedule.defaultMinWindowDuration
    var selectedWeekdays: Set<Weekday> = []
    var ruleStartTime: Date = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    var ruleEndTime: Date = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()

    private let createScheduleUseCase: any CreateScheduleUseCaseProtocol
    private let listSchedulesUseCase: any ListSchedulesUseCaseProtocol

    init(
        createScheduleUseCase: any CreateScheduleUseCaseProtocol,
        listSchedulesUseCase: any ListSchedulesUseCaseProtocol
    ) {
        self.createScheduleUseCase = createScheduleUseCase
        self.listSchedulesUseCase = listSchedulesUseCase
    }

    func onAppear() async {
        do {
            schedules = try await listSchedulesUseCase.listSchedules()
        } catch {
            schedules = []
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
            schedules.append(newSchedule)
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

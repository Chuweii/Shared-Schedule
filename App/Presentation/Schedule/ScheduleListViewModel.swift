import Foundation

@Observable
final class ScheduleListViewModel {
    private(set) var schedules: [Schedule] = []
    private(set) var inlineError: CreateScheduleError?
    var isCreateSheetPresented = false
    var titleDraft = ""
    var minDurationDraft: TimeInterval = Schedule.defaultMinWindowDuration

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
        titleDraft = ""
        minDurationDraft = Schedule.defaultMinWindowDuration
    }

    func didConfirmCreate() async {
        do {
            let newSchedule = try await createScheduleUseCase.createSchedule(
                title: titleDraft,
                minWindowDuration: minDurationDraft
            )
            schedules.append(newSchedule)
            isCreateSheetPresented = false
            inlineError = nil
            titleDraft = ""
            minDurationDraft = Schedule.defaultMinWindowDuration
        } catch {
            inlineError = error
        }
    }
}

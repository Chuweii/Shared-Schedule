import Foundation

@Observable
final class ScheduleDetailViewModel {
    private(set) var schedule: Schedule
    private(set) var inlineError: ScheduleMutationError?
    var isAddWindowSheetPresented = false
    var newWindowStart = Date()
    var newWindowEnd = Date().addingTimeInterval(3600)

    private let addWindowUseCase: any AddAvailabilityWindowUseCaseProtocol
    private let removeWindowUseCase: any RemoveAvailabilityWindowUseCaseProtocol

    init(
        schedule: Schedule,
        addWindowUseCase: any AddAvailabilityWindowUseCaseProtocol,
        removeWindowUseCase: any RemoveAvailabilityWindowUseCaseProtocol
    ) {
        self.schedule = schedule
        self.addWindowUseCase = addWindowUseCase
        self.removeWindowUseCase = removeWindowUseCase
    }

    func onAppear() async {}

    func didConfirmAddWindow() async {
        do {
            let updated = try await addWindowUseCase.addWindow(
                to: schedule.id,
                start: newWindowStart,
                end: newWindowEnd
            )
            schedule = updated
            isAddWindowSheetPresented = false
            inlineError = nil
            newWindowStart = Date()
            newWindowEnd = Date().addingTimeInterval(3600)
        } catch {
            inlineError = error
        }
    }

    func didCancelAddWindow() {
        isAddWindowSheetPresented = false
        inlineError = nil
        newWindowStart = Date()
        newWindowEnd = Date().addingTimeInterval(3600)
    }

    func didTapDelete(windowID: AvailabilityWindowID) async {
        do {
            let updated = try await removeWindowUseCase.removeWindow(
                windowID,
                from: schedule.id
            )
            schedule = updated
        } catch {
            inlineError = error
        }
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct ScheduleListViewModelRulesTests {

    private func makeSUT() -> (vm: ScheduleListViewModel, fakeCreate: FakeCreateScheduleUseCase) {
        let fakeCreate = FakeCreateScheduleUseCase()
        let fakeList = FakeListSchedulesUseCase()
        let vm = ScheduleListViewModel(
            createScheduleUseCase: fakeCreate,
            listSchedulesUseCase: fakeList
        )
        return (vm, fakeCreate)
    }

    @Test("didConfirmCreate 帶 weekdays 與時段 → schedule 有 rules")
    func didConfirmCreate_withWeekdays_createsScheduleWithRules() async throws {
        // Given
        let (vm, _) = makeSUT()
        vm.isCreateSheetPresented = true
        vm.titleDraft = "瑜珈初階"
        vm.selectedWeekdays = [.monday, .friday]
        vm.ruleStartTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        vm.ruleEndTime = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date())!

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.schedules.count == 1)
        #expect(vm.schedules[0].rules.count == 2)
        #expect(vm.isCreateSheetPresented == false)
    }

    @Test("didConfirmCreate 不選 weekday → inline error、sheet 不關")
    func didConfirmCreate_noWeekdays_showsError() async {
        // Given
        let (vm, fakeCreate) = makeSUT()
        fakeCreate.errorToThrow = .noWeekdaysSelected
        vm.isCreateSheetPresented = true
        vm.titleDraft = "瑜珈初階"
        vm.selectedWeekdays = []

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.inlineError == .noWeekdaysSelected)
        #expect(vm.isCreateSheetPresented == true)
        #expect(vm.schedules.isEmpty)
    }

    @Test("建立後 state 重設")
    func didConfirmCreate_resetsState() async {
        // Given
        let (vm, _) = makeSUT()
        vm.isCreateSheetPresented = true
        vm.titleDraft = "瑜珈初階"
        vm.selectedWeekdays = [.monday, .wednesday]
        vm.ruleStartTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date())!

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.titleDraft.isEmpty)
        #expect(vm.selectedWeekdays.isEmpty)
        #expect(vm.minDurationDraft == Schedule.defaultMinWindowDuration)
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct ScheduleListViewModelTests {

    private func makeSUT(
        createResult: Schedule? = nil,
        createError: CreateScheduleError? = nil,
        existingSchedules: [Schedule] = []
    ) -> (vm: ScheduleListViewModel, fakeCreate: FakeCreateScheduleUseCase, fakeList: FakeListSchedulesUseCase) {
        let fakeCreate = FakeCreateScheduleUseCase()
        fakeCreate.resultToReturn = createResult
        fakeCreate.errorToThrow = createError

        let fakeList = FakeListSchedulesUseCase()
        fakeList.schedulesToReturn = existingSchedules

        let vm = ScheduleListViewModel(
            createScheduleUseCase: fakeCreate,
            listSchedulesUseCase: fakeList
        )
        return (vm, fakeCreate, fakeList)
    }

    // MARK: - onAppear

    @Test("onAppear 載入空 repository 時 schedules 為空")
    func onAppear_empty_schedulesIsEmpty() async {
        // Given
        let (vm, _, _) = makeSUT()

        // When
        await vm.onAppear()

        // Then
        #expect(vm.schedules.isEmpty)
        #expect(vm.inlineError == nil)
    }

    @Test("onAppear 載入既有 1 份 schedule")
    func onAppear_oneSchedule_populatesList() async {
        // Given
        let existing = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let (vm, _, _) = makeSUT(existingSchedules: [existing])

        // When
        await vm.onAppear()

        // Then
        #expect(vm.schedules.count == 1)
        #expect(vm.schedules[0].title == "瑜珈初階")
    }

    // MARK: - didConfirmCreate

    @Test("輸入有效 title 並送出建立 — schedule 出現、sheet 關閉")
    func didConfirmCreate_validTitle_appendsAndDismisses() async {
        // Given
        let (vm, _, _) = makeSUT()
        vm.isCreateSheetPresented = true
        vm.titleDraft = "瑜珈初階"

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.schedules.count == 1)
        #expect(vm.schedules[0].title == "瑜珈初階")
        #expect(vm.isCreateSheetPresented == false)
        #expect(vm.inlineError == nil)
    }

    @Test("輸入空白 title 並送出 — inline error、sheet 不關")
    func didConfirmCreate_blankTitle_showsError() async {
        // Given
        let (vm, _, _) = makeSUT(createError: .blankTitle)
        vm.isCreateSheetPresented = true
        vm.titleDraft = ""

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.inlineError == .blankTitle)
        #expect(vm.isCreateSheetPresented == true)
        #expect(vm.schedules.isEmpty)
    }

    @Test("輸入純空白字元 title 並送出 — inline error")
    func didConfirmCreate_whitespaceOnlyTitle_showsError() async {
        // Given
        let (vm, _, _) = makeSUT(createError: .blankTitle)
        vm.isCreateSheetPresented = true
        vm.titleDraft = "   "

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.inlineError == .blankTitle)
        #expect(vm.isCreateSheetPresented == true)
        #expect(vm.schedules.isEmpty)
    }

    @Test("有錯誤狀態後修正 title 重送 — error 清空、成功建立")
    func didConfirmCreate_afterError_fixAndRetry_succeeds() async {
        // Given
        let (vm, fakeCreate, _) = makeSUT(createError: .blankTitle)
        vm.isCreateSheetPresented = true
        vm.titleDraft = ""
        await vm.didConfirmCreate()
        #expect(vm.inlineError == .blankTitle)

        // When — fix title and clear error setting
        fakeCreate.errorToThrow = nil
        vm.titleDraft = "瑜珈初階"
        await vm.didConfirmCreate()

        // Then
        #expect(vm.inlineError == nil)
        #expect(vm.schedules.count == 1)
        #expect(vm.isCreateSheetPresented == false)
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct ScheduleListViewModelTests {

    private func makeSUT(
        createResult: Schedule? = nil,
        createError: CreateScheduleError? = nil,
        existingSchedules: [Schedule] = [],
        listError: Error? = nil,
        joinedSchedules: [Schedule] = [],
        joinedError: Error? = nil
    ) -> (
        vm: ScheduleListViewModel,
        fakeCreate: FakeCreateScheduleUseCase,
        fakeList: FakeListSchedulesUseCase,
        fakeJoined: FakeListJoinedSchedulesUseCase
    ) {
        let fakeCreate = FakeCreateScheduleUseCase()
        fakeCreate.resultToReturn = createResult
        fakeCreate.errorToThrow = createError

        let fakeList = FakeListSchedulesUseCase()
        fakeList.schedulesToReturn = existingSchedules
        fakeList.errorToThrow = listError

        let fakeJoined = FakeListJoinedSchedulesUseCase()
        fakeJoined.schedulesToReturn = joinedSchedules
        fakeJoined.errorToThrow = joinedError

        let vm = ScheduleListViewModel(
            createScheduleUseCase: fakeCreate,
            listSchedulesUseCase: fakeList,
            listJoinedSchedulesUseCase: fakeJoined
        )
        return (vm, fakeCreate, fakeList, fakeJoined)
    }

    private struct TestError: Error {}

    // MARK: - onAppear

    @Test("onAppear 載入空 repository 時 ownedSchedules 為空")
    func onAppear_empty_ownedSchedulesIsEmpty() async {
        // Given
        let (vm, _, _, _) = makeSUT()

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.isEmpty)
        #expect(vm.inlineError == nil)
    }

    @Test("onAppear 載入既有 1 份 owned schedule")
    func onAppear_oneSchedule_populatesOwnedList() async {
        // Given
        let existing = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let (vm, _, _, _) = makeSUT(existingSchedules: [existing])

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.count == 1)
        #expect(vm.ownedSchedules[0].title == "瑜珈初階")
    }

    // MARK: - didConfirmCreate

    @Test("輸入有效 title 並送出建立 — schedule 出現在 owned、sheet 關閉")
    func didConfirmCreate_validTitle_appendsToOwnedAndDismisses() async {
        // Given
        let (vm, _, _, _) = makeSUT()
        vm.isCreateSheetPresented = true
        vm.titleDraft = "瑜珈初階"

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.ownedSchedules.count == 1)
        #expect(vm.ownedSchedules[0].title == "瑜珈初階")
        #expect(vm.isCreateSheetPresented == false)
        #expect(vm.inlineError == nil)
    }

    @Test("輸入空白 title 並送出 — inline error、sheet 不關")
    func didConfirmCreate_blankTitle_showsError() async {
        // Given
        let (vm, _, _, _) = makeSUT(createError: .blankTitle)
        vm.isCreateSheetPresented = true
        vm.titleDraft = ""

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.inlineError == .blankTitle)
        #expect(vm.isCreateSheetPresented == true)
        #expect(vm.ownedSchedules.isEmpty)
    }

    @Test("輸入純空白字元 title 並送出 — inline error")
    func didConfirmCreate_whitespaceOnlyTitle_showsError() async {
        // Given
        let (vm, _, _, _) = makeSUT(createError: .blankTitle)
        vm.isCreateSheetPresented = true
        vm.titleDraft = "   "

        // When
        await vm.didConfirmCreate()

        // Then
        #expect(vm.inlineError == .blankTitle)
        #expect(vm.isCreateSheetPresented == true)
        #expect(vm.ownedSchedules.isEmpty)
    }

    // MARK: - load error / retry

    @Test("onAppear owned repository 拋錯 — owned 清空且 ownedLoadError 被設")
    func onAppear_listFails_setsOwnedLoadError() async {
        // Given
        let (vm, _, _, _) = makeSUT(listError: TestError())

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.isEmpty)
        #expect(vm.ownedLoadError != nil)
    }

    @Test("retryOwned 在錯誤後成功 — ownedLoadError 清空、列表填入")
    func retryOwned_afterError_clearsErrorAndReloads() async {
        // Given — first attempt fails
        let (vm, _, fakeList, _) = makeSUT(listError: TestError())
        await vm.onAppear()
        #expect(vm.ownedLoadError != nil)

        // When — fix the underlying issue and retry
        let recovered = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        fakeList.errorToThrow = nil
        fakeList.schedulesToReturn = [recovered]
        await vm.retryOwned()

        // Then
        #expect(vm.ownedLoadError == nil)
        #expect(vm.ownedSchedules.count == 1)
        #expect(vm.ownedSchedules[0].title == "瑜珈初階")
    }

    @Test("有錯誤狀態後修正 title 重送 — error 清空、成功建立")
    func didConfirmCreate_afterError_fixAndRetry_succeeds() async {
        // Given
        let (vm, fakeCreate, _, _) = makeSUT(createError: .blankTitle)
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
        #expect(vm.ownedSchedules.count == 1)
        #expect(vm.isCreateSheetPresented == false)
    }

    // MARK: - Slice 3: two-section onAppear

    @Test("M1. onAppear owned + joined 都成功 — 兩個 array 都填、兩個 error nil")
    func onAppear_ownedAndJoinedBothSucceed_populatesBothSections() async {
        // Given
        let owned = Schedule(ownerID: UserID("teacher-001"), title: "我的瑜珈班")
        let joined = Schedule(ownerID: UserID("teacher-002"), title: "阿明的吉他課")
        let (vm, _, _, _) = makeSUT(
            existingSchedules: [owned],
            joinedSchedules: [joined]
        )

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.map(\.title) == ["我的瑜珈班"])
        #expect(vm.joinedSchedules.map(\.title) == ["阿明的吉他課"])
        #expect(vm.ownedLoadError == nil)
        #expect(vm.joinedLoadError == nil)
        #expect(vm.isFullScreenError == false)
    }

    @Test("M2. onAppear owned 成功、joined 失敗 — 只設 joinedLoadError、isFullScreenError 為 false")
    func onAppear_ownedSucceedsJoinedFails_setsJoinedErrorOnly() async {
        // Given
        let owned = Schedule(ownerID: UserID("teacher-001"), title: "我的瑜珈班")
        let (vm, _, _, _) = makeSUT(
            existingSchedules: [owned],
            joinedError: TestError()
        )

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.map(\.title) == ["我的瑜珈班"])
        #expect(vm.joinedSchedules.isEmpty)
        #expect(vm.ownedLoadError == nil)
        #expect(vm.joinedLoadError != nil)
        #expect(vm.isFullScreenError == false)
    }

    @Test("M3. onAppear owned 為空、joined 有 1 筆 — isEmpty 為 false（會顯示 joined section）")
    func onAppear_emptyOwnedAndOneJoined_isEmptyFalse() async {
        // Given
        let joined = Schedule(ownerID: UserID("teacher-002"), title: "阿明的吉他課")
        let (vm, _, _, _) = makeSUT(joinedSchedules: [joined])

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.isEmpty)
        #expect(vm.joinedSchedules.count == 1)
        #expect(vm.isEmpty == false)
    }

    @Test("M4. onAppear 兩邊都失敗 — 兩個 error 都設、isFullScreenError 為 true")
    func onAppear_bothFail_isFullScreenErrorTrue() async {
        // Given
        let (vm, _, _, _) = makeSUT(
            listError: TestError(),
            joinedError: TestError()
        )

        // When
        await vm.onAppear()

        // Then
        #expect(vm.ownedSchedules.isEmpty)
        #expect(vm.joinedSchedules.isEmpty)
        #expect(vm.ownedLoadError != nil)
        #expect(vm.joinedLoadError != nil)
        #expect(vm.isFullScreenError == true)
    }
}

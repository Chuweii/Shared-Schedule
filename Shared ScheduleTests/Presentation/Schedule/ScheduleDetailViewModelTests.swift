import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct ScheduleDetailViewModelTests {

    private static let t14 = Date(timeIntervalSince1970: 1_700_000_000)
    private static let t15 = t14.addingTimeInterval(3600)
    private static let t16 = t15.addingTimeInterval(3600)

    private func makeSchedule(
        windowCount: Int = 0,
        minWindowDuration: TimeInterval = 3600
    ) throws -> Schedule {
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階",
            minWindowDuration: minWindowDuration
        )
        for i in 0..<windowCount {
            let start = Self.t14.addingTimeInterval(Double(i) * 3600)
            let end = start.addingTimeInterval(3600)
            try schedule.addWindow(start: start, end: end)
        }
        return schedule
    }

    private func makeSUT(
        schedule: Schedule,
        addError: ScheduleMutationError? = nil,
        removeResult: Schedule? = nil
    ) -> (vm: ScheduleDetailViewModel, fakeAdd: FakeAddAvailabilityWindowUseCase, fakeRemove: FakeRemoveAvailabilityWindowUseCase) {
        let fakeAdd = FakeAddAvailabilityWindowUseCase()
        fakeAdd.errorToThrow = addError

        let fakeRemove = FakeRemoveAvailabilityWindowUseCase()
        fakeRemove.resultToReturn = removeResult

        let vm = ScheduleDetailViewModel(
            schedule: schedule,
            addWindowUseCase: fakeAdd,
            removeWindowUseCase: fakeRemove
        )
        return (vm, fakeAdd, fakeRemove)
    }

    // MARK: - onAppear

    @Test("onAppear 進入有 2 windows 的 schedule")
    func onAppear_twoWindows_populatesState() async throws {
        // Given
        let schedule = try makeSchedule(windowCount: 2)
        let (vm, _, _) = makeSUT(schedule: schedule)

        // When
        await vm.onAppear()

        // Then
        #expect(vm.schedule.windows.count == 2)
        #expect(vm.inlineError == nil)
    }

    // MARK: - didConfirmAddWindow

    @Test("送出合法 window — window 出現、sheet 關閉")
    func didConfirmAddWindow_valid_appendsAndDismisses() async throws {
        // Given
        let schedule = try makeSchedule()
        var expectedSchedule = schedule
        try expectedSchedule.addWindow(start: Self.t14, end: Self.t15)

        let (vm, fakeAdd, _) = makeSUT(schedule: schedule)
        fakeAdd.resultToReturn = expectedSchedule
        vm.isAddWindowSheetPresented = true
        vm.newWindowStart = Self.t14
        vm.newWindowEnd = Self.t15

        // When
        await vm.didConfirmAddWindow()

        // Then
        #expect(vm.schedule.windows.count == 1)
        #expect(vm.isAddWindowSheetPresented == false)
        #expect(vm.inlineError == nil)
    }

    @Test("送出 overlapping window — inline error、sheet 不關")
    func didConfirmAddWindow_overlapping_showsError() async throws {
        // Given
        let schedule = try makeSchedule(windowCount: 1)
        let (vm, _, _) = makeSUT(
            schedule: schedule,
            addError: .scheduleError(.overlapping)
        )
        vm.isAddWindowSheetPresented = true
        vm.newWindowStart = Self.t14.addingTimeInterval(1800)
        vm.newWindowEnd = Self.t15.addingTimeInterval(1800)

        // When
        await vm.didConfirmAddWindow()

        // Then
        #expect(vm.inlineError == .scheduleError(.overlapping))
        #expect(vm.isAddWindowSheetPresented == true)
        #expect(vm.schedule.windows.count == 1)
    }

    @Test("送出低於最短長度的 window — inline error")
    func didConfirmAddWindow_belowMinDuration_showsError() async throws {
        // Given
        let schedule = try makeSchedule()
        let (vm, _, _) = makeSUT(
            schedule: schedule,
            addError: .scheduleError(.belowMinimumDuration)
        )
        vm.isAddWindowSheetPresented = true
        vm.newWindowStart = Self.t14
        vm.newWindowEnd = Self.t14.addingTimeInterval(1800) // 30 min, but min is 60

        // When
        await vm.didConfirmAddWindow()

        // Then
        #expect(vm.inlineError == .scheduleError(.belowMinimumDuration))
        #expect(vm.isAddWindowSheetPresented == true)
    }

    @Test("送出 end 早於 start 的 window — inline error")
    func didConfirmAddWindow_invalidRange_showsError() async throws {
        // Given
        let schedule = try makeSchedule()
        let (vm, _, _) = makeSUT(
            schedule: schedule,
            addError: .scheduleError(.invalidRange)
        )
        vm.isAddWindowSheetPresented = true
        vm.newWindowStart = Self.t15
        vm.newWindowEnd = Self.t14

        // When
        await vm.didConfirmAddWindow()

        // Then
        #expect(vm.inlineError == .scheduleError(.invalidRange))
        #expect(vm.isAddWindowSheetPresented == true)
    }

    @Test("有錯誤狀態後修正並重送合法 window — error 清空")
    func didConfirmAddWindow_afterError_fixAndRetry_succeeds() async throws {
        // Given
        let schedule = try makeSchedule()
        let (vm, fakeAdd, _) = makeSUT(
            schedule: schedule,
            addError: .scheduleError(.overlapping)
        )
        vm.isAddWindowSheetPresented = true
        vm.newWindowStart = Self.t14
        vm.newWindowEnd = Self.t15
        await vm.didConfirmAddWindow()
        #expect(vm.inlineError != nil)

        // When — fix the error and retry
        fakeAdd.errorToThrow = nil
        var updatedSchedule = schedule
        try updatedSchedule.addWindow(start: Self.t14, end: Self.t15)
        fakeAdd.resultToReturn = updatedSchedule

        await vm.didConfirmAddWindow()

        // Then
        #expect(vm.inlineError == nil)
        #expect(vm.schedule.windows.count == 1)
        #expect(vm.isAddWindowSheetPresented == false)
    }

    // MARK: - didTapDelete

    @Test("點擊刪除指定 windowID — window 從列表移除")
    func didTapDelete_existingWindow_removesFromList() async throws {
        // Given
        let schedule = try makeSchedule(windowCount: 1)
        let windowID = schedule.windows[0].id
        let emptySchedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")

        let (vm, _, _) = makeSUT(
            schedule: schedule,
            removeResult: emptySchedule
        )

        // When
        await vm.didTapDelete(windowID: windowID)

        // Then
        #expect(vm.schedule.windows.isEmpty)
    }
}

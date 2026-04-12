import Testing
import Foundation
@testable import Shared_Schedule

struct ScheduleTests {

    // MARK: - 建立 Schedule

    @Test("以預設最短時段長度建立空 Schedule")
    func createEmptySchedule_withDefaultMinWindowDuration_succeeds() {
        // Given
        let ownerID = UserID("teacher-001")

        // When
        let schedule = Schedule(ownerID: ownerID, title: "瑜珈初階")

        // Then
        #expect(schedule.ownerID == ownerID)
        #expect(schedule.title == "瑜珈初階")
        #expect(schedule.minWindowDuration == 3600)
        #expect(schedule.windows.isEmpty)
    }

    @Test("以自訂最短時段長度建立空 Schedule")
    func createEmptySchedule_withCustomMinWindowDuration_succeeds() {
        // Given
        let ownerID = UserID("teacher-001")

        // When
        let schedule = Schedule(
            ownerID: ownerID,
            title: "試課",
            minWindowDuration: 1800
        )

        // Then
        #expect(schedule.minWindowDuration == 1800)
        #expect(schedule.windows.isEmpty)
    }

    // MARK: - 新增 window 成功路徑

    @Test("新增合法 window 到空 Schedule")
    func addWindow_validToEmptySchedule_succeeds() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)

        // When
        try schedule.addWindow(start: start, end: end)

        // Then
        #expect(schedule.windows.count == 1)
        #expect(schedule.windows[0].start == start)
        #expect(schedule.windows[0].end == end)
    }

    @Test("新增接在既有 window 後方的 window 不算 overlap")
    func addWindow_touchingAfter_succeeds() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        let t16 = t15.addingTimeInterval(3600)
        try schedule.addWindow(start: t14, end: t15)

        // When
        try schedule.addWindow(start: t15, end: t16)

        // Then
        #expect(schedule.windows.count == 2)
    }

    @Test("新增接在既有 window 前方的 window 不算 overlap")
    func addWindow_touchingBefore_succeeds() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        let t13 = t14.addingTimeInterval(-3600)
        try schedule.addWindow(start: t14, end: t15)

        // When
        try schedule.addWindow(start: t13, end: t14)

        // Then
        #expect(schedule.windows.count == 2)
    }

    @Test("新增恰好等於最短時段長度的 window")
    func addWindow_exactlyAtMinimumDuration_succeeds() throws {
        // Given
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "試課",
            minWindowDuration: 1800
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1800)

        // When
        try schedule.addWindow(start: start, end: end)

        // Then
        #expect(schedule.windows.count == 1)
        #expect(schedule.windows[0].duration == 1800)
    }

    // MARK: - 新增 window range 錯誤

    @Test("新增 start 等於 end 的 window 應 throw invalidRange")
    func addWindow_startEqualsEnd_throwsInvalidRange() {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let t = Date(timeIntervalSince1970: 1_700_000_000)

        // When / Then
        #expect(throws: ScheduleError.invalidRange) {
            try schedule.addWindow(start: t, end: t)
        }
        #expect(schedule.windows.isEmpty)
    }

    @Test("新增 start 晚於 end 的 window 應 throw invalidRange")
    func addWindow_startAfterEnd_throwsInvalidRange() {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let later = Date(timeIntervalSince1970: 1_700_000_000).addingTimeInterval(3600)
        let earlier = Date(timeIntervalSince1970: 1_700_000_000)

        // When / Then
        #expect(throws: ScheduleError.invalidRange) {
            try schedule.addWindow(start: later, end: earlier)
        }
        #expect(schedule.windows.isEmpty)
    }

    // MARK: - 新增 window 長度錯誤

    @Test("新增短於最短時段長度的 window 應 throw belowMinimumDuration")
    func addWindow_belowMinimumDuration_throwsBelowMinimumDuration() {
        // Given
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階",
            minWindowDuration: 3600
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3540) // 59 分鐘

        // When / Then
        #expect(throws: ScheduleError.belowMinimumDuration) {
            try schedule.addWindow(start: start, end: end)
        }
        #expect(schedule.windows.isEmpty)
    }

    // MARK: - 新增 window 重疊錯誤

    @Test("新增與既有 window 部分重疊於右的 window 應 throw overlapping")
    func addWindow_partialOverlapRight_throwsOverlapping() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        let t1430 = t14.addingTimeInterval(1800)
        let t1530 = t15.addingTimeInterval(1800)
        try schedule.addWindow(start: t14, end: t15)

        // When / Then
        #expect(throws: ScheduleError.overlapping) {
            try schedule.addWindow(start: t1430, end: t1530)
        }
        #expect(schedule.windows.count == 1)
    }

    @Test("新增與既有 window 部分重疊於左的 window 應 throw overlapping")
    func addWindow_partialOverlapLeft_throwsOverlapping() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        let t1330 = t14.addingTimeInterval(-1800)
        let t1430 = t14.addingTimeInterval(1800)
        try schedule.addWindow(start: t14, end: t15)

        // When / Then
        #expect(throws: ScheduleError.overlapping) {
            try schedule.addWindow(start: t1330, end: t1430)
        }
        #expect(schedule.windows.count == 1)
    }

    @Test("新增完全包在既有 window 內部的 window 應 throw overlapping")
    func addWindow_nestedInside_throwsOverlapping() throws {
        // Given
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階",
            minWindowDuration: 900 // 15 分鐘，才塞得下 30 分鐘的 nested window
        )
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        let t1415 = t14.addingTimeInterval(900)
        let t1445 = t14.addingTimeInterval(2700)
        try schedule.addWindow(start: t14, end: t15)

        // When / Then
        #expect(throws: ScheduleError.overlapping) {
            try schedule.addWindow(start: t1415, end: t1445)
        }
        #expect(schedule.windows.count == 1)
    }

    @Test("新增完全包住既有 window 的 window 應 throw overlapping")
    func addWindow_nestedContains_throwsOverlapping() throws {
        // Given
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階",
            minWindowDuration: 900
        )
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        let t1415 = t14.addingTimeInterval(900)
        let t1445 = t14.addingTimeInterval(2700)
        try schedule.addWindow(start: t1415, end: t1445)

        // When / Then
        #expect(throws: ScheduleError.overlapping) {
            try schedule.addWindow(start: t14, end: t15)
        }
        #expect(schedule.windows.count == 1)
    }

    @Test("新增與既有 window 時間完全相同的 window 應 throw overlapping")
    func addWindow_exactDuplicate_throwsOverlapping() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let t14 = Date(timeIntervalSince1970: 1_700_000_000)
        let t15 = t14.addingTimeInterval(3600)
        try schedule.addWindow(start: t14, end: t15)

        // When / Then
        #expect(throws: ScheduleError.overlapping) {
            try schedule.addWindow(start: t14, end: t15)
        }
        #expect(schedule.windows.count == 1)
    }

    // MARK: - 刪除 window

    @Test("刪除既有 window 後 windows 為空")
    func removeWindow_existing_leavesEmptyList() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let windowID = AvailabilityWindowID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)
        try schedule.addWindow(id: windowID, start: start, end: end)

        // When
        schedule.removeWindow(id: windowID)

        // Then
        #expect(schedule.windows.isEmpty)
    }

    @Test("刪除不存在的 window id 為 no-op 且不 throw")
    func removeWindow_nonExistentID_isNoOp() {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let someID = AvailabilityWindowID()

        // When
        schedule.removeWindow(id: someID)

        // Then
        #expect(schedule.windows.isEmpty)
    }

    @Test("刪除 window 後以相同時段重新加入應成功")
    func removeWindow_thenReAddSameRange_succeeds() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let windowID = AvailabilityWindowID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)
        try schedule.addWindow(id: windowID, start: start, end: end)
        schedule.removeWindow(id: windowID)

        // When
        try schedule.addWindow(start: start, end: end)

        // Then
        #expect(schedule.windows.count == 1)
        #expect(schedule.windows[0].start == start)
        #expect(schedule.windows[0].end == end)
    }
}

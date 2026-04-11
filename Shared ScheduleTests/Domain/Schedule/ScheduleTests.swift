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
}

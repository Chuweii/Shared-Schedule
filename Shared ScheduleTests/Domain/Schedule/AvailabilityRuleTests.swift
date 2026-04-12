import Testing
import Foundation
@testable import Shared_Schedule

struct AvailabilityRuleTests {

    // MARK: - addRule

    @Test("新增有效 rule 到空 Schedule")
    func addRule_valid_succeeds() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let startTime = try TimeOfDay(hour: 9, minute: 0)
        let endTime = try TimeOfDay(hour: 18, minute: 0)

        // When
        try schedule.addRule(weekday: .monday, startTime: startTime, endTime: endTime)

        // Then
        #expect(schedule.rules.count == 1)
        #expect(schedule.rules[0].weekday == .monday)
        #expect(schedule.rules[0].startTime == startTime)
        #expect(schedule.rules[0].endTime == endTime)
    }

    @Test("新增 startTime >= endTime 的 rule 應 throw invalidRange")
    func addRule_startAfterEnd_throwsInvalidRange() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")

        // When / Then
        #expect(throws: ScheduleError.invalidRange) {
            try schedule.addRule(
                weekday: .monday,
                startTime: try TimeOfDay(hour: 18, minute: 0),
                endTime: try TimeOfDay(hour: 9, minute: 0)
            )
        }
        #expect(schedule.rules.isEmpty)
    }

    @Test("新增 duration 短於 minWindowDuration 的 rule 應 throw ruleTooShort")
    func addRule_durationBelowMinWindow_throwsRuleTooShort() throws {
        // Given — minWindowDuration = 90 minutes (5400 seconds)
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階",
            minWindowDuration: 5400
        )

        // When / Then — rule is 60 minutes (9:00-10:00), less than 90
        #expect(throws: ScheduleError.ruleTooShort) {
            try schedule.addRule(
                weekday: .monday,
                startTime: try TimeOfDay(hour: 9, minute: 0),
                endTime: try TimeOfDay(hour: 10, minute: 0)
            )
        }
        #expect(schedule.rules.isEmpty)
    }

    @Test("同一 weekday 已有 rule 時再加一條應 throw ruleOverlapping")
    func addRule_sameWeekday_throwsRuleOverlapping() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        try schedule.addRule(
            weekday: .monday,
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 18, minute: 0)
        )

        // When / Then
        #expect(throws: ScheduleError.ruleOverlapping) {
            try schedule.addRule(
                weekday: .monday,
                startTime: try TimeOfDay(hour: 10, minute: 0),
                endTime: try TimeOfDay(hour: 12, minute: 0)
            )
        }
        #expect(schedule.rules.count == 1)
    }

    @Test("不同 weekday 各加一條 rule 應都成功")
    func addRule_differentWeekdays_succeeds() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")

        // When
        try schedule.addRule(
            weekday: .monday,
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 18, minute: 0)
        )
        try schedule.addRule(
            weekday: .wednesday,
            startTime: try TimeOfDay(hour: 13, minute: 0),
            endTime: try TimeOfDay(hour: 17, minute: 0)
        )

        // Then
        #expect(schedule.rules.count == 2)
    }

    // MARK: - removeRule

    @Test("刪除 rule 後 rules 為空")
    func removeRule_existing_removesSuccessfully() throws {
        // Given
        var schedule = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let ruleID = AvailabilityRuleID()
        try schedule.addRule(
            id: ruleID,
            weekday: .monday,
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 18, minute: 0)
        )

        // When
        schedule.removeRule(id: ruleID)

        // Then
        #expect(schedule.rules.isEmpty)
    }
}

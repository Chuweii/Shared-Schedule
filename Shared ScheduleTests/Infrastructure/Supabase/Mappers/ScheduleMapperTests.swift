import Testing
import Foundation
@testable import Shared_Schedule

struct ScheduleMapperTests {

    private let scheduleId = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    private let ownerId = UUID(uuidString: "a1b2c3d4-e5f6-7890-abcd-ef1234567890")!
    private let ruleId = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    private let windowId = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!

    // MARK: - toDomain — minimal schedule

    @Test("DTO 沒有 rules 與 windows — domain 兩個列表都是空")
    func toDomain_minimalDTO_returnsEmptyRulesAndWindows() {
        // Given
        let dto = ScheduleDTO(
            id: scheduleId,
            ownerId: ownerId,
            title: "瑜珈初階",
            minWindowDuration: 3600,
            createdAt: nil,
            updatedAt: nil,
            availabilityRules: nil,
            availabilityWindows: nil
        )

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.id.rawValue == scheduleId)
        #expect(schedule.ownerID.rawValue == ownerId.uuidString)
        #expect(schedule.title == "瑜珈初階")
        #expect(schedule.minWindowDuration == 3600)
        #expect(schedule.rules.isEmpty)
        #expect(schedule.windows.isEmpty)
    }

    // MARK: - toDomain — rules

    @Test("DTO 含 rules — Postgres TIME 字串 09:00:00 解析成 TimeOfDay")
    func toDomain_withRule_parsesTimeString() throws {
        // Given
        let ruleDTO = AvailabilityRuleDTO(
            id: ruleId,
            scheduleId: scheduleId,
            weekday: Weekday.monday.rawValue,
            startTime: "09:00:00",
            endTime: "18:00:00"
        )
        let dto = makeScheduleDTO(rules: [ruleDTO])

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.rules.count == 1)
        let rule = schedule.rules[0]
        #expect(rule.id.rawValue == ruleId)
        #expect(rule.weekday == .monday)
        #expect(rule.startTime == (try TimeOfDay(hour: 9, minute: 0)))
        #expect(rule.endTime == (try TimeOfDay(hour: 18, minute: 0)))
    }

    @Test("DTO 含無效 weekday — 該 rule 被略過、不丟錯")
    func toDomain_invalidWeekday_skipsRule() {
        // Given
        let invalidRuleDTO = AvailabilityRuleDTO(
            id: ruleId,
            scheduleId: scheduleId,
            weekday: 99,  // out of 1-7
            startTime: "09:00:00",
            endTime: "18:00:00"
        )
        let dto = makeScheduleDTO(rules: [invalidRuleDTO])

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.rules.isEmpty)
    }

    @Test("DTO 含格式錯誤的 time 字串 — 該 rule 被略過")
    func toDomain_malformedTimeString_skipsRule() {
        // Given
        let ruleDTO = AvailabilityRuleDTO(
            id: ruleId,
            scheduleId: scheduleId,
            weekday: Weekday.monday.rawValue,
            startTime: "abc",
            endTime: "def"
        )
        let dto = makeScheduleDTO(rules: [ruleDTO])

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.rules.isEmpty)
    }

    // MARK: - toDomain — windows

    @Test("DTO 含 windows — ISO8601 with fractional seconds 字串解析成 Date")
    func toDomain_withWindow_parsesISO8601String() {
        // Given
        let windowDTO = AvailabilityWindowDTO(
            id: windowId,
            scheduleId: scheduleId,
            startAt: "2026-05-04T09:00:00.000Z",
            endAt: "2026-05-04T10:00:00.000Z"
        )
        let dto = makeScheduleDTO(windows: [windowDTO])

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.windows.count == 1)
        let window = schedule.windows[0]
        #expect(window.id.rawValue == windowId)
        #expect(window.end.timeIntervalSince(window.start) == 3600)
    }

    @Test("Postgres TIMESTAMPTZ 格式（無 fractional seconds）也能解析 — regression for round-trip integration bug")
    func toDomain_postgresTimestamptzWithoutFractionalSeconds_parsesCorrectly() {
        // Given — PostgREST emits `2026-05-02T15:00:00+00:00` for whole-second values
        let windowDTO = AvailabilityWindowDTO(
            id: windowId,
            scheduleId: scheduleId,
            startAt: "2026-05-02T15:00:00+00:00",
            endAt: "2026-05-02T16:00:00+00:00"
        )
        let dto = makeScheduleDTO(windows: [windowDTO])

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.windows.count == 1)
        #expect(schedule.windows.first?.end.timeIntervalSince(schedule.windows.first!.start) == 3600)
    }

    @Test("DTO 含格式錯誤的 ISO 字串 — 該 window 被略過")
    func toDomain_malformedISOString_skipsWindow() {
        // Given
        let windowDTO = AvailabilityWindowDTO(
            id: windowId,
            scheduleId: scheduleId,
            startAt: "not-a-date",
            endAt: "also-not-a-date"
        )
        let dto = makeScheduleDTO(windows: [windowDTO])

        // When
        let schedule = ScheduleMapper.toDomain(dto)

        // Then
        #expect(schedule.windows.isEmpty)
    }

    // MARK: - toInsertDTO

    @Test("Domain → ScheduleInsertDTO — 欄位完整對應")
    func toInsertDTO_mapsAllFields() {
        // Given
        let schedule = Schedule(
            id: ScheduleID(scheduleId),
            ownerID: UserID(ownerId.uuidString),
            title: "瑜珈初階",
            minWindowDuration: 1800
        )

        // When
        let insertDTO = ScheduleMapper.toInsertDTO(schedule)

        // Then
        #expect(insertDTO.id == scheduleId)
        #expect(insertDTO.ownerId == ownerId)
        #expect(insertDTO.title == "瑜珈初階")
        #expect(insertDTO.minWindowDuration == 1800)
    }

    // MARK: - toRuleInsertDTOs

    @Test("Rule → InsertDTO — TimeOfDay 格式化為 HH:MM:00 字串")
    func toRuleInsertDTOs_formatsTimeAsHHMM00() throws {
        // Given
        var schedule = Schedule(
            id: ScheduleID(scheduleId),
            ownerID: UserID(ownerId.uuidString),
            title: "瑜珈初階"
        )
        try schedule.addRule(
            id: AvailabilityRuleID(ruleId),
            weekday: .tuesday,
            startTime: try TimeOfDay(hour: 9, minute: 30),
            endTime: try TimeOfDay(hour: 17, minute: 45)
        )

        // When
        let dtos = ScheduleMapper.toRuleInsertDTOs(schedule)

        // Then
        #expect(dtos.count == 1)
        let dto = dtos[0]
        #expect(dto.id == ruleId)
        #expect(dto.scheduleId == scheduleId)
        #expect(dto.weekday == Weekday.tuesday.rawValue)
        #expect(dto.startTime == "09:30:00")
        #expect(dto.endTime == "17:45:00")
    }

    // MARK: - toWindowInsertDTOs

    @Test("Window → InsertDTO — Date 格式化為 ISO8601 字串可被相同 formatter 反向解析")
    func toWindowInsertDTOs_roundTripsThroughISO8601Formatter() throws {
        // Given
        var schedule = Schedule(
            id: ScheduleID(scheduleId),
            ownerID: UserID(ownerId.uuidString),
            title: "瑜珈初階"
        )
        let start = Date(timeIntervalSince1970: 1_777_734_000)  // arbitrary stable instant
        let end = start.addingTimeInterval(3600)
        try schedule.addWindow(id: AvailabilityWindowID(windowId), start: start, end: end)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        // When
        let dtos = ScheduleMapper.toWindowInsertDTOs(schedule)

        // Then — string format should round-trip back to original instants
        #expect(dtos.count == 1)
        let dto = dtos[0]
        #expect(dto.id == windowId)
        #expect(dto.scheduleId == scheduleId)
        #expect(formatter.date(from: dto.startAt) == start)
        #expect(formatter.date(from: dto.endAt) == end)
    }

    // MARK: - Helpers

    private func makeScheduleDTO(
        rules: [AvailabilityRuleDTO]? = nil,
        windows: [AvailabilityWindowDTO]? = nil
    ) -> ScheduleDTO {
        ScheduleDTO(
            id: scheduleId,
            ownerId: ownerId,
            title: "瑜珈初階",
            minWindowDuration: 3600,
            createdAt: nil,
            updatedAt: nil,
            availabilityRules: rules,
            availabilityWindows: windows
        )
    }
}

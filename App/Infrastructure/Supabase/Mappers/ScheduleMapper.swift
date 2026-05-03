import Foundation

enum ScheduleMapper {

    // MARK: - DTO → Domain

    static func toDomain(_ dto: ScheduleDTO) -> Schedule {
        var schedule = Schedule(
            id: ScheduleID(dto.id),
            ownerID: UserID(dto.ownerId.uuidString),
            title: dto.title,
            minWindowDuration: TimeInterval(dto.minWindowDuration)
        )

        if let ruleDTOs = dto.availabilityRules {
            for ruleDTO in ruleDTOs {
                guard let weekday = Weekday(rawValue: ruleDTO.weekday),
                      let (startHour, startMinute) = parseTime(ruleDTO.startTime),
                      let (endHour, endMinute) = parseTime(ruleDTO.endTime),
                      let startTime = try? TimeOfDay(hour: startHour, minute: startMinute),
                      let endTime = try? TimeOfDay(hour: endHour, minute: endMinute)
                else { continue }

                try? schedule.addRule(
                    id: AvailabilityRuleID(ruleDTO.id),
                    weekday: weekday,
                    startTime: startTime,
                    endTime: endTime
                )
            }
        }

        if let windowDTOs = dto.availabilityWindows {
            for windowDTO in windowDTOs {
                guard let start = parseTimestamptz(windowDTO.startAt),
                      let end = parseTimestamptz(windowDTO.endAt)
                else { continue }

                try? schedule.addWindow(
                    id: AvailabilityWindowID(windowDTO.id),
                    start: start,
                    end: end
                )
            }
        }

        return schedule
    }

    // MARK: - Domain → Insert DTOs

    static func toInsertDTO(_ schedule: Schedule) -> ScheduleInsertDTO {
        ScheduleInsertDTO(
            id: schedule.id.rawValue,
            ownerId: UUID(uuidString: schedule.ownerID.rawValue) ?? UUID(),
            title: schedule.title,
            minWindowDuration: Int(schedule.minWindowDuration)
        )
    }

    static func toRuleInsertDTOs(_ schedule: Schedule) -> [AvailabilityRuleInsertDTO] {
        schedule.rules.map { rule in
            AvailabilityRuleInsertDTO(
                id: rule.id.rawValue,
                scheduleId: schedule.id.rawValue,
                weekday: rule.weekday.rawValue,
                startTime: formatTime(rule.startTime),
                endTime: formatTime(rule.endTime)
            )
        }
    }

    static func toWindowInsertDTOs(_ schedule: Schedule) -> [AvailabilityWindowInsertDTO] {
        return schedule.windows.map { window in
            AvailabilityWindowInsertDTO(
                id: window.id.rawValue,
                scheduleId: schedule.id.rawValue,
                startAt: formatTimestamptz(window.start),
                endAt: formatTimestamptz(window.end)
            )
        }
    }

    // MARK: - Helpers

    private static func parseTime(_ timeString: String) -> (hour: Int, minute: Int)? {
        let parts = timeString.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1])
        else { return nil }
        return (hour, minute)
    }

    private static func formatTime(_ time: TimeOfDay) -> String {
        String(format: "%02d:%02d:00", time.hour, time.minute)
    }

    // PostgREST surfaces TIMESTAMPTZ in two main shapes depending on whether
    // the value carries sub-second precision: `2026-05-02T15:00:00+00:00`
    // (whole second) or `2026-05-02T15:00:00.500+00:00` (millisecond).
    // Try with-fractional first, then without — covers both.
    static func parseTimestamptz(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let withoutFractional = ISO8601DateFormatter()
        withoutFractional.formatOptions = [.withInternetDateTime]
        return withoutFractional.date(from: string)
    }

    static func formatTimestamptz(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

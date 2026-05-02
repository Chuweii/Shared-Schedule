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
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            for windowDTO in windowDTOs {
                guard let start = isoFormatter.date(from: windowDTO.startAt),
                      let end = isoFormatter.date(from: windowDTO.endAt)
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
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return schedule.windows.map { window in
            AvailabilityWindowInsertDTO(
                id: window.id.rawValue,
                scheduleId: schedule.id.rawValue,
                startAt: isoFormatter.string(from: window.start),
                endAt: isoFormatter.string(from: window.end)
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
}

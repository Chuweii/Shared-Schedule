import Testing
@testable import Shared_Schedule

struct TimeOfDayTests {

    @Test("建立有效 TimeOfDay")
    func createTimeOfDay_valid_succeeds() throws {
        // Given / When
        let time = try TimeOfDay(hour: 9, minute: 30)

        // Then
        #expect(time.hour == 9)
        #expect(time.minute == 30)
        #expect(time.totalMinutes == 570)
    }

    @Test("hour 超過 23 的 TimeOfDay 應 throw invalidHour")
    func createTimeOfDay_invalidHour_throws() {
        // When / Then
        #expect(throws: TimeOfDayError.invalidHour) {
            try TimeOfDay(hour: 24, minute: 0)
        }
    }

    @Test("minute 超過 59 的 TimeOfDay 應 throw invalidMinute")
    func createTimeOfDay_invalidMinute_throws() {
        // When / Then
        #expect(throws: TimeOfDayError.invalidMinute) {
            try TimeOfDay(hour: 9, minute: 60)
        }
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

struct BookingTests {

    private let scheduleID = ScheduleID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
    private let studentID = UserID("c3d4e5f6-a7b8-9012-cdef-345678901234")

    @Test("建立 endsAt 晚於 startsAt 且時長一致的 booking，成功")
    func createBooking_validRangeAndDuration_succeeds() throws {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(3600)
        let createdAt = Date(timeIntervalSince1970: 1_779_999_000)

        // When
        let booking = try Booking(
            scheduleID: scheduleID,
            studentID: studentID,
            startsAt: startsAt,
            endsAt: endsAt,
            durationSeconds: 3600,
            createdAt: createdAt
        )

        // Then
        #expect(booking.scheduleID == scheduleID)
        #expect(booking.studentID == studentID)
        #expect(booking.startsAt == startsAt)
        #expect(booking.endsAt == endsAt)
        #expect(booking.durationSeconds == 3600)
        #expect(booking.createdAt == createdAt)
    }

    @Test("建立 endsAt 等於 startsAt 的 booking，throws .invalidRange")
    func createBooking_endsEqualStarts_throwsInvalidRange() {
        // Given
        let same = Date(timeIntervalSince1970: 1_780_000_000)

        // When / Then
        #expect(throws: BookingError.invalidRange) {
            _ = try Booking(
                scheduleID: scheduleID,
                studentID: studentID,
                startsAt: same,
                endsAt: same,
                durationSeconds: 0
            )
        }
    }

    @Test("建立 durationSeconds 為 0 的 booking，throws .invalidDuration")
    func createBooking_zeroDuration_throwsInvalidDuration() {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(3600)

        // When / Then
        #expect(throws: BookingError.invalidDuration) {
            _ = try Booking(
                scheduleID: scheduleID,
                studentID: studentID,
                startsAt: startsAt,
                endsAt: endsAt,
                durationSeconds: 0
            )
        }
    }

    @Test("時長與 durationSeconds 不一致（30 分區間但 durationSeconds = 3600），throws .durationMismatch")
    func createBooking_durationDoesNotMatchInterval_throwsDurationMismatch() {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(1800)  // 30 minutes

        // When / Then
        #expect(throws: BookingError.durationMismatch) {
            _ = try Booking(
                scheduleID: scheduleID,
                studentID: studentID,
                startsAt: startsAt,
                endsAt: endsAt,
                durationSeconds: 3600  // claims 60 minutes
            )
        }
    }

    @Test("matches(_:)：start 與時長皆對齊回 true；start 偏移 2 秒回 false")
    func matches_returnsTrueWhenAligned_falseWhenStartDrifts() throws {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(3600)
        let booking = try Booking(
            scheduleID: scheduleID,
            studentID: studentID,
            startsAt: startsAt,
            endsAt: endsAt,
            durationSeconds: 3600
        )
        let alignedSlot = ComputedSlot(start: startsAt, end: endsAt)
        let driftedSlot = ComputedSlot(
            start: startsAt.addingTimeInterval(2),
            end: endsAt.addingTimeInterval(2)
        )

        // When / Then
        #expect(booking.matches(alignedSlot) == true)
        #expect(booking.matches(driftedSlot) == false)
    }
}

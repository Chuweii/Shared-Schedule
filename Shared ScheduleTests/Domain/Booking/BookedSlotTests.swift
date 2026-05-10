import Testing
import Foundation
@testable import Shared_Schedule

struct BookedSlotTests {

    @Test("建立 endsAt 晚於 startsAt 且時長一致的 BookedSlot，成功")
    func createBookedSlot_validRangeAndDuration_succeeds() throws {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(3600)

        // When
        let bookedSlot = try BookedSlot(
            startsAt: startsAt,
            endsAt: endsAt,
            durationSeconds: 3600
        )

        // Then
        #expect(bookedSlot.startsAt == startsAt)
        #expect(bookedSlot.endsAt == endsAt)
        #expect(bookedSlot.durationSeconds == 3600)
    }

    @Test("建立 endsAt 等於 startsAt 的 BookedSlot，throws .invalidRange")
    func createBookedSlot_endsEqualStarts_throwsInvalidRange() {
        // Given
        let same = Date(timeIntervalSince1970: 1_780_000_000)

        // When / Then
        #expect(throws: BookingError.invalidRange) {
            _ = try BookedSlot(
                startsAt: same,
                endsAt: same,
                durationSeconds: 0
            )
        }
    }

    @Test("建立 durationSeconds 為 0 的 BookedSlot，throws .invalidDuration")
    func createBookedSlot_zeroDuration_throwsInvalidDuration() {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(3600)

        // When / Then
        #expect(throws: BookingError.invalidDuration) {
            _ = try BookedSlot(
                startsAt: startsAt,
                endsAt: endsAt,
                durationSeconds: 0
            )
        }
    }

    @Test("matches(_:)：start 與時長皆對齊回 true；start 偏移 2 秒回 false")
    func matches_returnsTrueWhenAligned_falseWhenStartDrifts() throws {
        // Given
        let startsAt = Date(timeIntervalSince1970: 1_780_000_000)
        let endsAt = startsAt.addingTimeInterval(3600)
        let bookedSlot = try BookedSlot(
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
        #expect(bookedSlot.matches(alignedSlot) == true)
        #expect(bookedSlot.matches(driftedSlot) == false)
    }
}

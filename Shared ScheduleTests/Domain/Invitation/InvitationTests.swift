import Testing
import Foundation
@testable import Shared_Schedule

struct InvitationTests {

    private let scheduleID = ScheduleID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)

    @Test("建立 expiresAt 晚於 createdAt 的 invitation，成功")
    func createInvitation_expiresAfterCreated_succeeds() throws {
        // Given
        let createdAt = Date(timeIntervalSince1970: 1_777_734_000)
        let expiresAt = createdAt.addingTimeInterval(60 * 60 * 24 * 7)

        // When
        let invitation = try Invitation(
            scheduleID: scheduleID,
            token: try InvitationToken("ABCD1234"),
            expiresAt: expiresAt,
            createdAt: createdAt
        )

        // Then
        #expect(invitation.scheduleID == scheduleID)
        #expect(invitation.token.rawValue == "ABCD1234")
        #expect(invitation.expiresAt == expiresAt)
        #expect(invitation.createdAt == createdAt)
    }

    @Test("建立 expiresAt 等於 createdAt 的 invitation，throws .invalidExpiry")
    func createInvitation_expiresEqualCreated_throwsInvalidExpiry() {
        // Given
        let same = Date(timeIntervalSince1970: 1_777_734_000)

        // When / Then
        #expect(throws: InvitationError.invalidExpiry) {
            _ = try Invitation(
                scheduleID: scheduleID,
                expiresAt: same,
                createdAt: same
            )
        }
    }

    @Test("建立 expiresAt 早於 createdAt 的 invitation，throws .invalidExpiry")
    func createInvitation_expiresBeforeCreated_throwsInvalidExpiry() {
        // Given
        let createdAt = Date(timeIntervalSince1970: 1_777_734_000)
        let expiresAt = createdAt.addingTimeInterval(-1)

        // When / Then
        #expect(throws: InvitationError.invalidExpiry) {
            _ = try Invitation(
                scheduleID: scheduleID,
                expiresAt: expiresAt,
                createdAt: createdAt
            )
        }
    }

    @Test("isExpired(at:) 在邊界回傳正確：前=false、相等=true、後=true")
    func isExpired_boundaryReturnsCorrectly() throws {
        // Given
        let createdAt = Date(timeIntervalSince1970: 1_777_734_000)
        let expiresAt = createdAt.addingTimeInterval(3600)
        let invitation = try Invitation(
            scheduleID: scheduleID,
            expiresAt: expiresAt,
            createdAt: createdAt
        )

        // When / Then
        #expect(invitation.isExpired(at: expiresAt.addingTimeInterval(-1)) == false)
        #expect(invitation.isExpired(at: expiresAt) == true)
        #expect(invitation.isExpired(at: expiresAt.addingTimeInterval(1)) == true)
    }
}

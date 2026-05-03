import Testing
import Foundation
@testable import Shared_Schedule

struct ListInvitationsUseCaseTests {

    private static let teacher001 = UserID("teacher-001")
    private static let teacher002 = UserID("teacher-002")

    private func makeSUT(
        ownerID: UserID = teacher001,
        seed: [Invitation] = []
    ) async throws -> (
        useCase: ListInvitationsUseCase,
        scheduleID: ScheduleID
    ) {
        let scheduleRepo = InMemoryScheduleRepository()
        let invitationRepo = FakeInvitationRepository()
        invitationRepo.preload(seed)
        let userProvider = InMemoryCurrentUserProvider()  // teacher-001

        let scheduleID = ScheduleID()
        try await scheduleRepo.save(Schedule(
            id: scheduleID,
            ownerID: ownerID,
            title: "Sample"
        ))

        let useCase = ListInvitationsUseCase(
            scheduleRepository: scheduleRepo,
            invitationRepository: invitationRepo,
            currentUserProvider: userProvider
        )
        return (useCase, scheduleID)
    }

    // MARK: - L1

    @Test("Owner list 自己 schedule 的 invitations（已有 2 筆），回傳 2 筆按 createdAt desc")
    func listInvitations_ownerWithTwo_returnsNewestFirst() async throws {
        // Given
        let scheduleID = ScheduleID()
        let earlierAt = Date(timeIntervalSince1970: 1_777_734_000)
        let laterAt = earlierAt.addingTimeInterval(3600)

        let earlier = try Invitation(
            scheduleID: scheduleID,
            token: try InvitationToken("AAAA1111"),
            expiresAt: earlierAt.addingTimeInterval(60 * 60 * 24 * 7),
            createdAt: earlierAt
        )
        let later = try Invitation(
            scheduleID: scheduleID,
            token: try InvitationToken("BBBB2222"),
            expiresAt: laterAt.addingTimeInterval(60 * 60 * 24 * 7),
            createdAt: laterAt
        )

        // Build SUT manually so we can place the schedule with the same ID
        let scheduleRepo = InMemoryScheduleRepository()
        let invitationRepo = FakeInvitationRepository()
        invitationRepo.preload([earlier, later])
        let userProvider = InMemoryCurrentUserProvider()
        try await scheduleRepo.save(Schedule(
            id: scheduleID,
            ownerID: Self.teacher001,
            title: "Sample"
        ))
        let useCase = ListInvitationsUseCase(
            scheduleRepository: scheduleRepo,
            invitationRepository: invitationRepo,
            currentUserProvider: userProvider
        )

        // When
        let result = try await useCase.listInvitations(for: scheduleID)

        // Then
        #expect(result.count == 2)
        #expect(result[0] == later)
        #expect(result[1] == earlier)
    }

    // MARK: - L2

    @Test("Owner list 沒 invitation 的 schedule，回傳空陣列")
    func listInvitations_ownerEmpty_returnsEmpty() async throws {
        // Given
        let (useCase, scheduleID) = try await makeSUT()

        // When
        let result = try await useCase.listInvitations(for: scheduleID)

        // Then
        #expect(result.isEmpty)
    }

    // MARK: - L3

    @Test("非 owner 嘗試 list invitations，throws .notOwner")
    func listInvitations_nonOwner_throwsNotOwner() async throws {
        // Given — schedule owned by teacher-002, currentUser is teacher-001
        let (useCase, scheduleID) = try await makeSUT(ownerID: Self.teacher002)

        // When / Then
        await #expect(throws: ListInvitationsError.notOwner) {
            _ = try await useCase.listInvitations(for: scheduleID)
        }
    }
}

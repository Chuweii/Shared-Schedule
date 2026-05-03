import Testing
import Foundation
@testable import Shared_Schedule

struct CreateInvitationUseCaseTests {

    private static let teacher001 = UserID("teacher-001")
    private static let teacher002 = UserID("teacher-002")
    private static let fixedNow = Date(timeIntervalSince1970: 1_777_734_000)

    private func makeSUT(
        ownerID: UserID = teacher001
    ) async throws -> (
        useCase: CreateInvitationUseCase,
        scheduleRepo: InMemoryScheduleRepository,
        invitationRepo: FakeInvitationRepository,
        scheduleID: ScheduleID
    ) {
        let scheduleRepo = InMemoryScheduleRepository()
        let invitationRepo = FakeInvitationRepository()
        let userProvider = InMemoryCurrentUserProvider()  // currentUser.id = teacher-001

        let scheduleID = ScheduleID()
        let schedule = Schedule(
            id: scheduleID,
            ownerID: ownerID,
            title: "Sample"
        )
        try await scheduleRepo.save(schedule)

        let useCase = CreateInvitationUseCase(
            scheduleRepository: scheduleRepo,
            invitationRepository: invitationRepo,
            currentUserProvider: userProvider,
            now: { Self.fixedNow }
        )
        return (useCase, scheduleRepo, invitationRepo, scheduleID)
    }

    // MARK: - C1

    @Test("Owner 對自己 schedule 建立 invitation，repo 多一筆、expiresAt = now + 7 天")
    func createInvitation_ownerOwnSchedule_succeeds() async throws {
        // Given
        let (useCase, _, invitationRepo, scheduleID) = try await makeSUT()

        // When
        let invitation = try await useCase.createInvitation(scheduleID: scheduleID)

        // Then
        #expect(invitation.scheduleID == scheduleID)
        #expect(invitation.createdAt == Self.fixedNow)
        #expect(invitation.expiresAt == Self.fixedNow.addingTimeInterval(60 * 60 * 24 * 7))
        #expect(invitation.token.rawValue.count == InvitationToken.length)
        // Verify it was actually saved
        let saved = try await invitationRepo.fetch(id: invitation.id)
        #expect(saved == invitation)
    }

    // MARK: - C2

    @Test("非 owner 嘗試建立 invitation，throws .notOwner、repo 無變化")
    func createInvitation_nonOwner_throwsNotOwner() async throws {
        // Given — schedule owned by teacher-002 but currentUser is teacher-001
        let (useCase, _, invitationRepo, scheduleID) = try await makeSUT(ownerID: Self.teacher002)

        // When / Then
        await #expect(throws: CreateInvitationError.notOwner) {
            _ = try await useCase.createInvitation(scheduleID: scheduleID)
        }
        #expect(invitationRepo.saveCount == 0)
    }

    // MARK: - C3

    @Test("對不存在 scheduleID 建立 invitation，throws .scheduleNotFound")
    func createInvitation_nonExistentSchedule_throwsScheduleNotFound() async throws {
        // Given
        let scheduleRepo = InMemoryScheduleRepository()
        let invitationRepo = FakeInvitationRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = CreateInvitationUseCase(
            scheduleRepository: scheduleRepo,
            invitationRepository: invitationRepo,
            currentUserProvider: userProvider
        )
        let fakeID = ScheduleID()

        // When / Then
        await #expect(throws: CreateInvitationError.scheduleNotFound) {
            _ = try await useCase.createInvitation(scheduleID: fakeID)
        }
    }

    // MARK: - C4

    @Test("Repository save 失敗，throws .persistenceFailure")
    func createInvitation_repositorySaveFails_throwsPersistenceFailure() async throws {
        // Given
        let (useCase, _, invitationRepo, scheduleID) = try await makeSUT()
        invitationRepo.saveError = FakeInvitationRepositoryError.forced

        // When / Then
        await #expect(throws: CreateInvitationError.persistenceFailure) {
            _ = try await useCase.createInvitation(scheduleID: scheduleID)
        }
    }
}

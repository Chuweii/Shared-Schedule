import Testing
import Foundation
@testable import Shared_Schedule

struct RedeemInvitationUseCaseTests {

    private static let teacherID = UserID("teacher-001")
    private static let fixedJoinedAt = Date(timeIntervalSince1970: 1_777_734_000)

    private func makeRedemption(scheduleID: ScheduleID) -> InvitationRedemption {
        InvitationRedemption(
            scheduleID: scheduleID,
            membershipID: MembershipID(),
            joinedAt: Self.fixedJoinedAt
        )
    }

    private func makeSUT(
        seedSchedule: Bool = true
    ) async throws -> (
        useCase: RedeemInvitationUseCase,
        invitationRepo: FakeInvitationRepository,
        scheduleRepo: InMemoryScheduleRepository,
        scheduleID: ScheduleID,
        token: InvitationToken
    ) {
        let invitationRepo = FakeInvitationRepository()
        let scheduleRepo = InMemoryScheduleRepository()
        let scheduleID = ScheduleID()
        if seedSchedule {
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: Self.teacherID,
                title: "Yoga 101"
            ))
        }
        let useCase = RedeemInvitationUseCase(
            invitationRepository: invitationRepo,
            scheduleRepository: scheduleRepo
        )
        let token = try InvitationToken("ABCD1234")
        return (useCase, invitationRepo, scheduleRepo, scheduleID, token)
    }

    // MARK: - R1

    @Test("R1. Valid token、schedule 存在，回傳對應 Schedule")
    func redeemInvitation_valid_returnsSchedule() async throws {
        // Given
        let (useCase, invitationRepo, _, scheduleID, token) = try await makeSUT()
        invitationRepo.redeemResultToReturn = makeRedemption(scheduleID: scheduleID)

        // When
        let schedule = try await useCase.redeemInvitation(token: token)

        // Then
        #expect(schedule.id == scheduleID)
        #expect(schedule.title == "Yoga 101")
        #expect(invitationRepo.redeemCount == 1)
        #expect(invitationRepo.lastRedeemedToken == token)
    }

    // MARK: - R2

    @Test("R2. Token 不存在，throws .invalidToken")
    func redeemInvitation_invalidToken_throwsInvalidToken() async throws {
        // Given
        let (useCase, invitationRepo, _, _, token) = try await makeSUT()
        invitationRepo.redeemErrorToThrow = .invalidToken

        // When / Then
        await #expect(throws: InvitationRedemptionError.invalidToken) {
            _ = try await useCase.redeemInvitation(token: token)
        }
    }

    // MARK: - R3

    @Test("R3. Token 已過期，throws .expired")
    func redeemInvitation_expired_throwsExpired() async throws {
        // Given
        let (useCase, invitationRepo, _, _, token) = try await makeSUT()
        invitationRepo.redeemErrorToThrow = .expired

        // When / Then
        await #expect(throws: InvitationRedemptionError.expired) {
            _ = try await useCase.redeemInvitation(token: token)
        }
    }

    // MARK: - R4

    @Test("R4. Current user 是 schedule owner，throws .selfRedemption")
    func redeemInvitation_selfRedemption_throwsSelfRedemption() async throws {
        // Given
        let (useCase, invitationRepo, _, _, token) = try await makeSUT()
        invitationRepo.redeemErrorToThrow = .selfRedemption

        // When / Then
        await #expect(throws: InvitationRedemptionError.selfRedemption) {
            _ = try await useCase.redeemInvitation(token: token)
        }
    }

    // MARK: - R5

    @Test("R5. Current user 已是 member，throws .alreadyMember")
    func redeemInvitation_alreadyMember_throwsAlreadyMember() async throws {
        // Given
        let (useCase, invitationRepo, _, _, token) = try await makeSUT()
        invitationRepo.redeemErrorToThrow = .alreadyMember

        // When / Then
        await #expect(throws: InvitationRedemptionError.alreadyMember) {
            _ = try await useCase.redeemInvitation(token: token)
        }
    }

    // MARK: - R6

    @Test("R6. Redeem 成功但後續 schedule fetch 失敗，throws .persistenceFailure")
    func redeemInvitation_scheduleFetchFails_throwsPersistenceFailure() async throws {
        // Given
        let invitationRepo = FakeInvitationRepository()
        let scheduleID = ScheduleID()
        invitationRepo.redeemResultToReturn = makeRedemption(scheduleID: scheduleID)

        let throwingScheduleRepo = ThrowingFetchScheduleRepository()
        let useCase = RedeemInvitationUseCase(
            invitationRepository: invitationRepo,
            scheduleRepository: throwingScheduleRepo
        )
        let token = try InvitationToken("ABCD1234")

        // When / Then
        await #expect(throws: InvitationRedemptionError.persistenceFailure) {
            _ = try await useCase.redeemInvitation(token: token)
        }
    }
}

/// Local test double — `InMemoryScheduleRepository` doesn't support a
/// fetch-fails affordance, and we don't want to leak that affordance into
/// production code just for one test.
private final class ThrowingFetchScheduleRepository: ScheduleRepositoryProtocol, @unchecked Sendable {
    func fetchAll(ownedBy ownerID: UserID) async throws -> [Schedule] { [] }
    func fetch(id: ScheduleID) async throws -> Schedule? { throw ForcedError.forced }
    func save(_ schedule: Schedule) async throws {}
    private enum ForcedError: Error { case forced }
}

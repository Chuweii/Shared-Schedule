import Testing
import Foundation
@testable import Shared_Schedule

struct ListOthersBookingsUseCaseTests {

    private static let scheduleID = ScheduleID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)

    private func makeSUT() -> (
        useCase: ListOthersBookingsUseCase,
        repo: FakeBookingRepository
    ) {
        let repo = FakeBookingRepository()
        let useCase = ListOthersBookingsUseCase(bookingRepository: repo)
        return (useCase, repo)
    }

    @Test("BO1. Repo 回 []，usecase 回 [] 且呼叫 1 次")
    func listOthers_repoReturnsEmpty_returnsEmpty() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.fetchOthersBookingsResult = []

        // When
        let result = try await useCase.listOthersBookings(scheduleID: Self.scheduleID)

        // Then
        #expect(result.isEmpty)
        #expect(repo.fetchOthersBookingsCount == 1)
        #expect(repo.lastFetchOthersBookingsScheduleID == Self.scheduleID)
    }

    @Test("BO2. Repo 回 2 筆 BookedSlot，usecase 透傳、order 不變")
    func listOthers_repoReturnsTwo_passesThroughInOrder() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        let earlier = try BookedSlot(
            startsAt: Date(timeIntervalSince1970: 1_780_000_000),
            endsAt: Date(timeIntervalSince1970: 1_780_003_600),
            durationSeconds: 3600
        )
        let later = try BookedSlot(
            startsAt: Date(timeIntervalSince1970: 1_780_010_000),
            endsAt: Date(timeIntervalSince1970: 1_780_013_600),
            durationSeconds: 3600
        )
        repo.fetchOthersBookingsResult = [earlier, later]

        // When
        let result = try await useCase.listOthersBookings(scheduleID: Self.scheduleID)

        // Then
        #expect(result == [earlier, later])
    }

    @Test("BO3a. Repo 拋 .notMember，usecase 透傳")
    func listOthers_repoThrowsNotMember_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.fetchOthersBookingsError = .notMember

        // When / Then
        await #expect(throws: ListOthersBookingsError.notMember) {
            _ = try await useCase.listOthersBookings(scheduleID: Self.scheduleID)
        }
    }

    @Test("BO3b. Repo 拋 .persistenceFailure，usecase 透傳")
    func listOthers_repoThrowsPersistenceFailure_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.fetchOthersBookingsError = .persistenceFailure

        // When / Then
        await #expect(throws: ListOthersBookingsError.persistenceFailure) {
            _ = try await useCase.listOthersBookings(scheduleID: Self.scheduleID)
        }
    }
}

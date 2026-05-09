import Testing
import Foundation
@testable import Shared_Schedule

struct ListMyBookingsUseCaseTests {

    private static let scheduleID = ScheduleID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
    private static let teacher001 = UserID("teacher-001")

    private func makeSUT(repoStudentID: UserID = teacher001) -> (
        useCase: ListMyBookingsUseCase,
        repo: FakeBookingRepository
    ) {
        let repo = FakeBookingRepository(studentIDForCreate: repoStudentID)
        let userProvider = InMemoryCurrentUserProvider()  // teacher-001
        let useCase = ListMyBookingsUseCase(
            bookingRepository: repo,
            currentUserProvider: userProvider
        )
        return (useCase, repo)
    }

    // MARK: - BL1

    @Test("已加入 schedule、有 0 筆 booking，回傳 []")
    func listMyBookings_empty_returnsEmpty() async throws {
        // Given
        let (useCase, repo) = makeSUT()

        // When
        let result = try await useCase.listMyBookings(scheduleID: Self.scheduleID)

        // Then
        #expect(result.isEmpty)
        #expect(repo.fetchAllCount == 1)
        #expect(repo.lastFetchAllParams?.scheduleID == Self.scheduleID)
        #expect(repo.lastFetchAllParams?.studentID == Self.teacher001)
    }

    // MARK: - BL2

    @Test("已加入 schedule、有 2 筆 booking，回傳 2 筆，按 startsAt asc")
    func listMyBookings_twoBookings_returnsSortedAsc() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        let later = try Booking(
            scheduleID: Self.scheduleID,
            studentID: Self.teacher001,
            startsAt: Date(timeIntervalSince1970: 1_780_000_000),
            endsAt: Date(timeIntervalSince1970: 1_780_003_600),
            durationSeconds: 3600
        )
        let earlier = try Booking(
            scheduleID: Self.scheduleID,
            studentID: Self.teacher001,
            startsAt: Date(timeIntervalSince1970: 1_779_900_000),
            endsAt: Date(timeIntervalSince1970: 1_779_903_600),
            durationSeconds: 3600
        )
        repo.preload([later, earlier])

        // When
        let result = try await useCase.listMyBookings(scheduleID: Self.scheduleID)

        // Then
        #expect(result.count == 2)
        #expect(result[0].id == earlier.id)
        #expect(result[1].id == later.id)
    }

    // MARK: - BL3

    @Test("Repo 拋錯，throws .persistenceFailure")
    func listMyBookings_repoThrows_throwsPersistenceFailure() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.fetchAllError = FakeBookingRepositoryError.forced

        // When / Then
        await #expect(throws: ListMyBookingsError.persistenceFailure) {
            _ = try await useCase.listMyBookings(scheduleID: Self.scheduleID)
        }
    }
}

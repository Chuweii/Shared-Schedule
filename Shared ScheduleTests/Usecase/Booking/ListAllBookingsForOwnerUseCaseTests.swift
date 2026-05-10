import Testing
import Foundation
@testable import Shared_Schedule

struct ListAllBookingsForOwnerUseCaseTests {

    private static let scheduleID = ScheduleID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)

    private func makeSUT() -> (
        useCase: ListAllBookingsForOwnerUseCase,
        repo: FakeBookingRepository
    ) {
        let repo = FakeBookingRepository()
        let useCase = ListAllBookingsForOwnerUseCase(bookingRepository: repo)
        return (useCase, repo)
    }

    @Test("Owner 對自己 schedule 撈到所有 booking + student email")
    func listAll_repoReturnsOwnerBookings_passesThrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        let booking = try Booking(
            scheduleID: Self.scheduleID,
            studentID: UserID("c3d4e5f6-a7b8-9012-cdef-345678901234"),
            startsAt: Date(timeIntervalSince1970: 1_780_000_000),
            endsAt: Date(timeIntervalSince1970: 1_780_003_600),
            durationSeconds: 3600
        )
        repo.fetchAllForOwnerResult = [
            OwnerBooking(booking: booking, studentEmail: "test-student-c@example.com")
        ]

        // When
        let result = try await useCase.listAllBookingsForOwner(scheduleID: Self.scheduleID)

        // Then
        #expect(repo.fetchAllForOwnerCount == 1)
        #expect(repo.lastFetchAllForOwnerScheduleID == Self.scheduleID)
        #expect(result.count == 1)
        #expect(result.first?.studentEmail == "test-student-c@example.com")
        #expect(result.first?.booking.id == booking.id)
    }

    @Test("Repo 拋 .notOwner，usecase 透傳")
    func listAll_repoThrowsNotOwner_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.fetchAllForOwnerError = .notOwner

        // When / Then
        await #expect(throws: ListAllBookingsForOwnerError.notOwner) {
            _ = try await useCase.listAllBookingsForOwner(scheduleID: Self.scheduleID)
        }
    }

    @Test("Repo 拋 .persistenceFailure，usecase 透傳")
    func listAll_repoThrowsPersistenceFailure_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.fetchAllForOwnerError = .persistenceFailure

        // When / Then
        await #expect(throws: ListAllBookingsForOwnerError.persistenceFailure) {
            _ = try await useCase.listAllBookingsForOwner(scheduleID: Self.scheduleID)
        }
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

struct CancelBookingUseCaseTests {

    private func makeSUT() -> (useCase: CancelBookingUseCase, repo: FakeBookingRepository) {
        let repo = FakeBookingRepository()
        let useCase = CancelBookingUseCase(bookingRepository: repo)
        return (useCase, repo)
    }

    // MARK: - BX1

    @Test("自己擁有的未來 booking 取消成功，repo.cancel 被呼叫")
    func cancelBooking_succeeds_repoCancelCalled() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        let bookingID = BookingID()

        // When
        try await useCase.cancelBooking(bookingID)

        // Then
        #expect(repo.cancelCount == 1)
        #expect(repo.lastCancelID == bookingID)
    }

    // MARK: - BX2

    @Test("Repo.cancel 拋 .notOwner，usecase 透傳")
    func cancelBooking_repoThrowsNotOwner_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.cancelError = .notOwner

        // When / Then
        await #expect(throws: CancelBookingError.notOwner) {
            try await useCase.cancelBooking(BookingID())
        }
    }

    // MARK: - BX3

    @Test("Repo.cancel 拋 .slotAlreadyStarted，usecase 透傳")
    func cancelBooking_repoThrowsSlotAlreadyStarted_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        repo.cancelError = .slotAlreadyStarted

        // When / Then
        await #expect(throws: CancelBookingError.slotAlreadyStarted) {
            try await useCase.cancelBooking(BookingID())
        }
    }

    // MARK: - BX4

    @Test("Repo.cancel 拋 .bookingNotFound 與 .persistenceFailure，usecase 各自透傳")
    func cancelBooking_repoThrowsBookingNotFoundOrPersistenceFailure_passthrough() async throws {
        // Given
        let (useCase, repo) = makeSUT()

        // When / Then — bookingNotFound
        repo.cancelError = .bookingNotFound
        await #expect(throws: CancelBookingError.bookingNotFound) {
            try await useCase.cancelBooking(BookingID())
        }

        // When / Then — persistenceFailure
        repo.cancelError = .persistenceFailure
        await #expect(throws: CancelBookingError.persistenceFailure) {
            try await useCase.cancelBooking(BookingID())
        }
    }
}

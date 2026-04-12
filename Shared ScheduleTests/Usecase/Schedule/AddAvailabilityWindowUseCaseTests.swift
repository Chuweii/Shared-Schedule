import Testing
import Foundation
@testable import Shared_Schedule

struct AddAvailabilityWindowUseCaseTests {

    private func makeSUT(
        ownerID: String = "teacher-001"
    ) async throws -> (
        useCase: AddAvailabilityWindowUseCase,
        repository: InMemoryScheduleRepository,
        schedule: Schedule
    ) {
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let schedule = Schedule(
            ownerID: UserID(ownerID),
            title: "瑜珈初階",
            minWindowDuration: 3600
        )
        try await repo.save(schedule)
        let useCase = AddAvailabilityWindowUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )
        return (useCase, repo, schedule)
    }

    @Test("Owner 送出合法 window — schedule 多一個 window")
    func addWindow_ownerValidWindow_succeeds() async throws {
        // Given
        let (useCase, repo, schedule) = try await makeSUT()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)

        // When
        let updated = try await useCase.addWindow(
            to: schedule.id,
            start: start,
            end: end
        )

        // Then
        #expect(updated.windows.count == 1)
        let saved = try await repo.fetch(id: schedule.id)
        #expect(saved?.windows.count == 1)
    }

    @Test("非 owner 嘗試送出 window — throws notOwner")
    func addWindow_notOwner_throwsNotOwner() async throws {
        // Given — schedule owned by teacher-002, but currentUser is teacher-001
        let (useCase, _, schedule) = try await makeSUT(ownerID: "teacher-002")

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)

        // When / Then
        await #expect(throws: ScheduleMutationError.notOwner) {
            try await useCase.addWindow(to: schedule.id, start: start, end: end)
        }
    }

    @Test("對不存在的 scheduleID 嘗試送出 window — throws scheduleNotFound")
    func addWindow_nonExistentSchedule_throwsScheduleNotFound() async {
        // Given
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = AddAvailabilityWindowUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )
        let fakeID = ScheduleID()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)

        // When / Then
        await #expect(throws: ScheduleMutationError.scheduleNotFound) {
            try await useCase.addWindow(to: fakeID, start: start, end: end)
        }
    }
}

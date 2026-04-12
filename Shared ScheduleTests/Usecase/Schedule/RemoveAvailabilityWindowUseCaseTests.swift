import Testing
import Foundation
@testable import Shared_Schedule

struct RemoveAvailabilityWindowUseCaseTests {

    @Test("Owner 移除既有 windowID — schedule 不再有該 window")
    func removeWindow_ownerExistingWindow_succeeds() async throws {
        // Given
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let windowID = AvailabilityWindowID()
        var schedule = Schedule(
            ownerID: UserID("teacher-001"),
            title: "瑜珈初階"
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)
        try schedule.addWindow(id: windowID, start: start, end: end)
        try await repo.save(schedule)

        let useCase = RemoveAvailabilityWindowUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )

        // When
        let updated = try await useCase.removeWindow(windowID, from: schedule.id)

        // Then
        #expect(updated.windows.isEmpty)
        let saved = try await repo.fetch(id: schedule.id)
        #expect(saved?.windows.isEmpty == true)
    }

    @Test("非 owner 嘗試移除 window — throws notOwner")
    func removeWindow_notOwner_throwsNotOwner() async throws {
        // Given — schedule owned by teacher-002
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let windowID = AvailabilityWindowID()
        var schedule = Schedule(
            ownerID: UserID("teacher-002"),
            title: "鋼琴入門"
        )
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)
        try schedule.addWindow(id: windowID, start: start, end: end)
        try await repo.save(schedule)

        let useCase = RemoveAvailabilityWindowUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )

        // When / Then
        await #expect(throws: ScheduleMutationError.notOwner) {
            try await useCase.removeWindow(windowID, from: schedule.id)
        }
    }
}

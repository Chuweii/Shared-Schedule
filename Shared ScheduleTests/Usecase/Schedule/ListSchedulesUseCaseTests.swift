import Testing
import Foundation
@testable import Shared_Schedule

struct ListSchedulesUseCaseTests {

    @Test("Repository 為空時查詢回傳空陣列")
    func listSchedules_emptyRepo_returnsEmpty() async throws {
        // Given
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = ListSchedulesUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )

        // When
        let result = try await useCase.listSchedules()

        // Then
        #expect(result.isEmpty)
    }

    @Test("Repository 含跨 owner 的多份 schedule 時只回傳屬於當前 user 的")
    func listSchedules_multipleOwners_filtersToCurrentUser() async throws {
        // Given
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = ListSchedulesUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )

        let scheduleA = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈初階")
        let scheduleB = Schedule(ownerID: UserID("teacher-001"), title: "瑜珈進階")
        let scheduleC = Schedule(ownerID: UserID("teacher-002"), title: "鋼琴入門")
        try await repo.save(scheduleA)
        try await repo.save(scheduleB)
        try await repo.save(scheduleC)

        // When
        let result = try await useCase.listSchedules()

        // Then
        #expect(result.count == 2)
        let titles = Set(result.map(\.title))
        #expect(titles == ["瑜珈初階", "瑜珈進階"])
    }
}

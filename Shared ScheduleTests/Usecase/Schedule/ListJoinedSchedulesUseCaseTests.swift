import Testing
import Foundation
@testable import Shared_Schedule

struct ListJoinedSchedulesUseCaseTests {

    @Test("沒 membership 時查詢回傳空陣列")
    func listJoined_emptyMemberships_returnsEmpty() async throws {
        // Given
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = ListJoinedSchedulesUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )

        // When
        let result = try await useCase.listJoinedSchedules()

        // Then
        #expect(result.isEmpty)
    }

    @Test("兩筆 membership 對應的 schedule 都會被回傳")
    func listJoined_twoMemberships_returnsBothSchedules() async throws {
        // Given
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let currentUserID = userProvider.currentUser.id
        let useCase = ListJoinedSchedulesUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )

        let scheduleA = Schedule(ownerID: UserID("teacher-002"), title: "阿明的吉他課")
        let scheduleB = Schedule(ownerID: UserID("teacher-003"), title: "Yoga with Anna")
        let scheduleC = Schedule(ownerID: UserID("teacher-004"), title: "未加入的課")
        try await repo.save(scheduleA)
        try await repo.save(scheduleB)
        try await repo.save(scheduleC)
        repo.addMembership(scheduleID: scheduleA.id, userID: currentUserID)
        repo.addMembership(scheduleID: scheduleB.id, userID: currentUserID)

        // When
        let result = try await useCase.listJoinedSchedules()

        // Then
        #expect(result.count == 2)
        let titles = Set(result.map(\.title))
        #expect(titles == ["阿明的吉他課", "Yoga with Anna"])
    }
}

import Testing
import Foundation
@testable import Shared_Schedule

struct CreateScheduleUseCaseTests {

    private func makeSUT() -> (
        useCase: CreateScheduleUseCase,
        repository: InMemoryScheduleRepository
    ) {
        let repo = InMemoryScheduleRepository()
        let userProvider = InMemoryCurrentUserProvider()
        let useCase = CreateScheduleUseCase(
            repository: repo,
            currentUserProvider: userProvider
        )
        return (useCase, repo)
    }

    @Test("以有效 title 與最短時段長度建立 Schedule")
    func createSchedule_validTitle_savesToRepo() async throws {
        // Given
        let (useCase, repo) = makeSUT()

        // When
        let template = AvailabilityRuleTemplate(
            weekdays: [.monday],
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 18, minute: 0)
        )
        let schedule = try await useCase.createSchedule(
            title: "瑜珈初階",
            minWindowDuration: 3600,
            ruleTemplate: template
        )

        // Then
        let saved = try await repo.fetch(id: schedule.id)
        #expect(saved != nil)
        #expect(saved?.title == "瑜珈初階")
        #expect(saved?.ownerID == UserID("teacher-001"))
        #expect(saved?.minWindowDuration == 3600)
        #expect(saved?.rules.count == 1)
    }

    @Test("以空白 title 建立 Schedule 應 throw blankTitle")
    func createSchedule_blankTitle_throwsBlankTitle() async {
        // Given
        let (useCase, repo) = makeSUT()

        // When / Then
        await #expect(throws: CreateScheduleError.blankTitle) {
            try await useCase.createSchedule(title: "   ", minWindowDuration: 3600, ruleTemplate: nil)
        }

        // Verify repo is untouched
        let all = try? await repo.fetchAll(ownedBy: UserID("teacher-001"))
        #expect(all?.isEmpty == true)
    }
}

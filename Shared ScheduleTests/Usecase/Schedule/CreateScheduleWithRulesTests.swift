import Testing
import Foundation
@testable import Shared_Schedule

struct CreateScheduleWithRulesTests {

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

    @Test("建立 Schedule 帶 weekdays 與時段規則")
    func createSchedule_withRuleTemplate_createsRules() async throws {
        // Given
        let (useCase, repo) = makeSUT()
        let template = AvailabilityRuleTemplate(
            weekdays: [.monday, .wednesday, .friday],
            startTime: try TimeOfDay(hour: 9, minute: 0),
            endTime: try TimeOfDay(hour: 18, minute: 0)
        )

        // When
        let schedule = try await useCase.createSchedule(
            title: "瑜珈初階",
            minWindowDuration: 3600,
            ruleTemplate: template
        )

        // Then
        #expect(schedule.rules.count == 3)
        let weekdays = Set(schedule.rules.map(\.weekday))
        #expect(weekdays == [.monday, .wednesday, .friday])

        let saved = try await repo.fetch(id: schedule.id)
        #expect(saved?.rules.count == 3)
    }

    @Test("建立 Schedule 不選任何 weekday")
    func createSchedule_noWeekdays_createsNoRules() async throws {
        // Given
        let (useCase, _) = makeSUT()

        // When
        let schedule = try await useCase.createSchedule(
            title: "瑜珈初階",
            minWindowDuration: 3600,
            ruleTemplate: nil
        )

        // Then
        #expect(schedule.rules.isEmpty)
    }
}

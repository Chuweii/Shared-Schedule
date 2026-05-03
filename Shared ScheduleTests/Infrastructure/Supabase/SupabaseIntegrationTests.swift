import Testing
import Foundation
import Auth
@testable import Shared_Schedule

// All Supabase integration tests live under one parent so `.serialized`
// applies across the whole tree — `SupabaseClientProvider.auth` is global,
// so two integration tests cannot share a process safely.
@Suite(.tags(.integration), .serialized)
struct SupabaseIntegrationTests {

    init() async throws {
        try await IntegrationTestSupport.requireLocalStack()
    }

    // MARK: - SupabaseScheduleRepository

    @Suite(.serialized) struct ScheduleRepository {

        @Test("Owner saves schedule with rules and windows then fetches it back — all fields round-trip")
        func ownerSaveAndFetch_roundTripsAllFields() async throws {
            // Given
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID(UUID())
            let ruleID = AvailabilityRuleID(UUID())
            let windowID = AvailabilityWindowID(UUID())
            let windowStart = Date(timeIntervalSince1970: 1_777_734_000)
            var schedule = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "Round-trip integration \(UUID().uuidString.prefix(8))",
                minWindowDuration: 1800
            )
            try schedule.addRule(
                id: ruleID,
                weekday: .monday,
                startTime: try TimeOfDay(hour: 9, minute: 30),
                endTime: try TimeOfDay(hour: 17, minute: 45)
            )
            try schedule.addWindow(
                id: windowID,
                start: windowStart,
                end: windowStart.addingTimeInterval(3600)
            )

            // When
            try await repo.save(schedule)
            let fetched = try await repo.fetch(id: scheduleID)

            // Then
            let result = try #require(fetched)
            #expect(result.id == scheduleID)
            #expect(result.ownerID.rawValue == userAID.uuidString)
            #expect(result.title == schedule.title)
            #expect(result.minWindowDuration == 1800)
            #expect(result.rules.count == 1)
            #expect(result.rules.first?.id == ruleID)
            #expect(result.rules.first?.weekday == .monday)
            #expect(result.rules.first?.startTime == (try TimeOfDay(hour: 9, minute: 30)))
            #expect(result.rules.first?.endTime == (try TimeOfDay(hour: 17, minute: 45)))
            #expect(result.windows.count == 1)
            #expect(result.windows.first?.id == windowID)
            #expect(result.windows.first?.start == windowStart)
            #expect(result.windows.first?.end == windowStart.addingTimeInterval(3600))
        }

        @Test("Saving the same schedule again with different rules — old rules are deleted, new rules persist")
        func resaveSchedule_replacesRulesEntirely() async throws {
            // Given
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID(UUID())
            var first = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "Replace rules test"
            )
            try first.addRule(
                id: AvailabilityRuleID(UUID()),
                weekday: .monday,
                startTime: try TimeOfDay(hour: 9, minute: 0),
                endTime: try TimeOfDay(hour: 18, minute: 0)
            )
            try await repo.save(first)

            // When: save same scheduleID with a different rule
            var second = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "Replace rules test"
            )
            try second.addRule(
                id: AvailabilityRuleID(UUID()),
                weekday: .friday,
                startTime: try TimeOfDay(hour: 14, minute: 0),
                endTime: try TimeOfDay(hour: 20, minute: 0)
            )
            try await repo.save(second)
            let fetched = try await repo.fetch(id: scheduleID)

            // Then: only the new rule remains
            let result = try #require(fetched)
            #expect(result.rules.count == 1)
            #expect(result.rules.first?.weekday == .friday)
        }

        @Test("Given user A owns a schedule, when user B fetches with B's own ownerID filter, then nothing of A's appears")
        func userBFetchesOwnSchedules_doesNotSeeUserAData() async throws {
            // Given: as user A, save a schedule
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID(UUID())
            let scheduleA = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "A's schedule \(UUID().uuidString.prefix(8))"
            )
            try await repo.save(scheduleA)

            // When: sign in as user B and fetch B's own schedules
            let userBID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let bSchedules = try await repo.fetchAll(ownedBy: UserID(userBID.uuidString))

            // Then: B sees nothing of A's
            #expect(!bSchedules.contains(where: { $0.id == scheduleID }))
        }

        @Test("Given user A owns a schedule, when user B tries to filter by user A's ownerID, then RLS strips the row and result is empty")
        func userBFiltersByUserAOwnerID_rlsReturnsEmpty() async throws {
            // Given
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID(UUID())
            let scheduleA = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "A's schedule \(UUID().uuidString.prefix(8))"
            )
            try await repo.save(scheduleA)

            // When: B impersonates the filter — RLS still applies
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let leak = try await repo.fetchAll(ownedBy: UserID(userAID.uuidString))

            // Then
            #expect(leak.isEmpty)
        }

        @Test("Given user A owns a schedule, when user B fetches by that schedule's ID directly, then RLS returns nil")
        func userBFetchesUserASchedulesByID_rlsReturnsNil() async throws {
            // Given
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID(UUID())
            let scheduleA = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "A's schedule \(UUID().uuidString.prefix(8))"
            )
            try await repo.save(scheduleA)

            // When
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let leak = try await repo.fetch(id: scheduleID)

            // Then
            #expect(leak == nil)
        }
    }

    // MARK: - SupabaseAuthCurrentUserProvider

    @Suite(.serialized) struct AuthCurrentUserProvider {

        @Test("Given a real Supabase sign-in, when the provider is updated from the auth user, then currentUser mirrors the auth identity")
        func realSignInUpdatesProvider_currentUserMatchesAuthUser() async throws {
            // Given
            let authUser = try await IntegrationTestSupport.signInReturningAuthUser(
                email: IntegrationTestSupport.userAEmail
            )

            // When
            let provider = SupabaseAuthCurrentUserProvider()
            provider.update(from: authUser)

            // Then
            #expect(provider.currentUser.id.rawValue == authUser.id.uuidString)
            #expect(provider.currentUser.displayName == IntegrationTestSupport.userAEmail)
        }

        @Test("Given two consecutive sign-ins (A then B), when the provider is updated from each session, then currentUser reflects the latest identity")
        func consecutiveSignIns_currentUserReflectsLatest() async throws {
            // Given: sign in as A
            let provider = SupabaseAuthCurrentUserProvider()
            let userA = try await IntegrationTestSupport.signInReturningAuthUser(
                email: IntegrationTestSupport.userAEmail
            )
            provider.update(from: userA)
            #expect(provider.currentUser.id.rawValue == userA.id.uuidString)

            // When: sign in as B
            let userB = try await IntegrationTestSupport.signInReturningAuthUser(
                email: IntegrationTestSupport.userBEmail
            )
            provider.update(from: userB)

            // Then
            #expect(provider.currentUser.id.rawValue == userB.id.uuidString)
            #expect(provider.currentUser.displayName == IntegrationTestSupport.userBEmail)
        }
    }
}

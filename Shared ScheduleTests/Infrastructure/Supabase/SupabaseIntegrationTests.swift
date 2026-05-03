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

    // MARK: - SupabaseInvitationRepository

    @Suite(.serialized) struct Invitations {

        @Test("Owner saves invitation then fetchAll for the schedule round-trips it")
        func ownerSaveAndFetchAllInvitations_roundTrips() async throws {
            // Given: as user A, save a schedule + an invitation for it
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID(UUID())
            let schedule = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "Invitation round-trip \(UUID().uuidString.prefix(8))"
            )
            try await scheduleRepo.save(schedule)

            let createdAt = Date()
            let invitationID = InvitationID(UUID())
            let invitation = try Invitation(
                id: invitationID,
                scheduleID: scheduleID,
                token: try InvitationToken("ABCD" + String(UUID().uuidString.prefix(4)).uppercased().filter({ "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains($0) }).padding(toLength: 4, withPad: "Z", startingAt: 0)),
                expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: createdAt
            )

            // When
            try await invitationRepo.save(invitation)
            let fetched = try await invitationRepo.fetchAll(for: scheduleID)

            // Then
            let result = try #require(fetched.first(where: { $0.id == invitationID }))
            #expect(result.scheduleID == scheduleID)
            #expect(result.token == invitation.token)
        }

        @Test("Given user A's invitation, when user B fetchAll on that schedule, then RLS strips and result is empty")
        func userBFetchesUserAInvitations_rlsReturnsEmpty() async throws {
            // Given: A saves invitation
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID(UUID())
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "RLS deny invitation \(UUID().uuidString.prefix(8))"
            ))
            let createdAt = Date()
            let invitation = try Invitation(
                scheduleID: scheduleID,
                expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: createdAt
            )
            try await invitationRepo.save(invitation)

            // When: switch to user B
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let leak = try await invitationRepo.fetchAll(for: scheduleID)

            // Then: RLS owner_select on invitations + member_select on schedules
            // both deny — B is neither owner nor member.
            #expect(leak.isEmpty)
        }

        @Test("Given a token already in use, when saving another invitation with the same token, then UNIQUE constraint throws")
        func duplicateToken_throwsUniqueViolation() async throws {
            // Given
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID(UUID())
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "Dup token \(UUID().uuidString.prefix(8))"
            ))
            // Pick a unique-per-run token to avoid clashing with prior runs.
            let sharedToken = try InvitationToken(
                String(UUID().uuidString.replacingOccurrences(of: "-", with: "").prefix(8)).uppercased()
                    .filter { "0123456789ABCDEFGHJKMNPQRSTVWXYZ".contains($0) }
                    .padding(toLength: 8, withPad: "Z", startingAt: 0)
            )
            let createdAt = Date()
            try await invitationRepo.save(try Invitation(
                scheduleID: scheduleID,
                token: sharedToken,
                expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: createdAt
            ))

            // When: a second invitation with the same token
            // Then: throws (Postgres UNIQUE violation surfaces as PostgrestError)
            await #expect(throws: (any Error).self) {
                try await invitationRepo.save(try Invitation(
                    scheduleID: scheduleID,
                    token: sharedToken,
                    expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                    createdAt: createdAt
                ))
            }
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

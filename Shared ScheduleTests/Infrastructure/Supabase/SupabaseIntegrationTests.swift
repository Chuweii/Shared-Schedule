import Testing
import Foundation
import Auth
import PostgREST
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

        @Test("Given user A owns a schedule B has no membership to, when user B filters by user A's ownerID, then RLS strips that specific schedule from the result")
        func userBFiltersByUserAOwnerID_rlsHidesNonMemberSchedules() async throws {
            // Given: A owns a fresh schedule that B is NOT a member of
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

            // Then: the freshly created schedule must not be visible to B.
            // Note: with Phase 3a's `member_select` policy, B *may* see other
            // schedules of A's that B has a membership to — so we can no
            // longer assert `leak.isEmpty`. The contract that matters is
            // that this specific non-member schedule stays hidden.
            #expect(!leak.contains(where: { $0.id == scheduleID }))
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

    // MARK: - SupabaseInvitationRepository.redeem (RPC + RLS)

    @Suite(.serialized) struct Redemption {

        @Test("INT-R1. User B redeem user A 的 valid token，建立 membership 並回 InvitationRedemption")
        func redeemValidToken_createsMembershipAndReturnsRedemption() async throws {
            // Given: user A own X、save invitation Y for X
            let (scheduleID, invitation) = try await Self.seedScheduleAndInvitation(
                titlePrefix: "INT-R1"
            )

            // When: user B redeems
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let invitationRepo = SupabaseInvitationRepository()
            let redemption = try await invitationRepo.redeem(token: invitation.token)

            // Then: result fields populate
            #expect(redemption.scheduleID == scheduleID)
            // joinedAt should be very close to now (within 30s — generous to
            // cover round-trip + clock skew of local supabase container).
            #expect(abs(redemption.joinedAt.timeIntervalSinceNow) < 30)
        }

        @Test("INT-R2. Redeem 已過期 token，throws .expired")
        func redeemExpiredToken_throwsExpired() async throws {
            // Given: user A creates schedule, then we raw-INSERT an expired
            // invitation (bypassing the Domain `expiresAt > createdAt`
            // guard — DB CHECK is `expires_at > created_at` which we honor
            // by setting created_at even further in the past).
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID()
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "INT-R2 expired \(UUID().uuidString.prefix(8))"
            ))
            let token = Self.uniqueToken()
            try await Self.rawInsertExpiredInvitation(
                scheduleID: scheduleID,
                token: token
            )

            // When: user B redeems the expired token
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let invitationRepo = SupabaseInvitationRepository()

            // Then
            await #expect(throws: InvitationRedemptionError.expired) {
                _ = try await invitationRepo.redeem(token: token)
            }
        }

        @Test("INT-R3. 同 user 第二次 redeem 同 token，throws .alreadyMember")
        func redeemTwiceSameUser_throwsAlreadyMember() async throws {
            // Given: A creates X + invitation, B redeems once successfully
            let (_, invitation) = try await Self.seedScheduleAndInvitation(
                titlePrefix: "INT-R3"
            )
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let invitationRepo = SupabaseInvitationRepository()
            _ = try await invitationRepo.redeem(token: invitation.token)

            // When: B redeems the same token again
            // Then
            await #expect(throws: InvitationRedemptionError.alreadyMember) {
                _ = try await invitationRepo.redeem(token: invitation.token)
            }
        }

        @Test("INT-R4. Owner self-redeem 自己 schedule 的 token，throws .selfRedemption")
        func ownerSelfRedeem_throwsSelfRedemption() async throws {
            // Given: A creates X + invitation Y (still on user A's session)
            let (_, invitation) = try await Self.seedScheduleAndInvitation(
                titlePrefix: "INT-R4"
            )
            // Stay as user A — owner attempts to redeem their own token
            let invitationRepo = SupabaseInvitationRepository()

            // Then
            await #expect(throws: InvitationRedemptionError.selfRedemption) {
                _ = try await invitationRepo.redeem(token: invitation.token)
            }
        }

        // MARK: - Helpers

        /// As user A, create a fresh schedule and a fresh valid invitation
        /// for it. Returns the scheduleID and the invitation. Leaves the
        /// session as user A — caller switches to user B as needed.
        private static func seedScheduleAndInvitation(
            titlePrefix: String
        ) async throws -> (ScheduleID, Invitation) {
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID()
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "\(titlePrefix) \(UUID().uuidString.prefix(8))"
            ))
            let createdAt = Date()
            let invitation = try Invitation(
                scheduleID: scheduleID,
                token: uniqueToken(),
                expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: createdAt
            )
            try await invitationRepo.save(invitation)
            return (scheduleID, invitation)
        }

        /// Crockford-safe random 8-char token built from a UUID prefix —
        /// avoids relying on `InvitationToken.generate()` so test failures
        /// are reproducible from the seed string.
        private static func uniqueToken() -> InvitationToken {
            let raw = UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .filter { InvitationToken.alphabetSet.contains($0) }
                .prefix(8)
                .padding(toLength: 8, withPad: "Z", startingAt: 0)
            return try! InvitationToken(raw)
        }

        /// Raw INSERT bypassing Domain's `expiresAt > createdAt` invariant
        /// while still satisfying the DB CHECK by pushing `created_at`
        /// further into the past than `expires_at`. Required because the
        /// Domain layer (correctly) refuses to construct an already-expired
        /// invitation. Must run while signed in as the schedule's owner so
        /// the `owner_insert` RLS policy on `invitations` allows it.
        private static func rawInsertExpiredInvitation(
            scheduleID: ScheduleID,
            token: InvitationToken
        ) async throws {
            struct ExpiredInvitationDTO: Codable, Sendable {
                let id: UUID
                let scheduleId: UUID
                let token: String
                let expiresAt: String
                let createdAt: String
            }
            let now = Date()
            let dto = ExpiredInvitationDTO(
                id: UUID(),
                scheduleId: scheduleID.rawValue,
                token: token.rawValue,
                expiresAt: ScheduleMapper.formatTimestamptz(now.addingTimeInterval(-86400)),     // -1 day
                createdAt: ScheduleMapper.formatTimestamptz(now.addingTimeInterval(-172800))    // -2 days
            )
            let session = try await SupabaseClientProvider.auth.session
            try await SupabaseClientProvider
                .database(accessToken: session.accessToken)
                .from("invitations")
                .insert(dto)
                .execute()
        }
    }

    // MARK: - SupabaseAuthCurrentUserProvider

    @Suite(.serialized) struct AuthCurrentUserProvider {

        @Test("Given a real sign-in, the provider hydrates displayName from user_profiles (Slice A)")
        func realSignInUpdatesProvider_displayNameFromProfile() async throws {
            // Given: user A has a seeded user_profiles row "Test Teacher A"
            let authUser = try await IntegrationTestSupport.signInReturningAuthUser(
                email: IntegrationTestSupport.userAEmail
            )

            // When
            let provider = SupabaseAuthCurrentUserProvider(
                userProfileRepository: SupabaseUserProfileRepository()
            )
            await provider.update(from: authUser)

            // Then
            #expect(provider.currentUser.id.rawValue == authUser.id.uuidString)
            #expect(provider.currentUser.displayName == "Test Teacher A")
        }

        @Test("Given consecutive sign-ins (A then B), provider tracks latest displayName from each profile")
        func consecutiveSignIns_currentUserReflectsLatest() async throws {
            // Given: sign in as A
            let provider = SupabaseAuthCurrentUserProvider(
                userProfileRepository: SupabaseUserProfileRepository()
            )
            let userA = try await IntegrationTestSupport.signInReturningAuthUser(
                email: IntegrationTestSupport.userAEmail
            )
            await provider.update(from: userA)
            #expect(provider.currentUser.displayName == "Test Teacher A")

            // When: sign in as B
            let userB = try await IntegrationTestSupport.signInReturningAuthUser(
                email: IntegrationTestSupport.userBEmail
            )
            await provider.update(from: userB)

            // Then
            #expect(provider.currentUser.id.rawValue == userB.id.uuidString)
            #expect(provider.currentUser.displayName == "Test Teacher B")
        }

        @Test("Auth-DN1. Fresh signed-up user without profile — provider falls back to email")
        func freshSignUpWithoutProfile_fallsBackToEmail() async throws {
            // Given: brand-new confirmed auth user, NO profile row
            let (freshEmail, _) = try await IntegrationTestSupport.signUpFreshUserConfirmed(
                prefix: "auth-dn1"
            )
            let authUser = try await SupabaseClientProvider.auth.session.user

            // When
            let provider = SupabaseAuthCurrentUserProvider(
                userProfileRepository: SupabaseUserProfileRepository()
            )
            await provider.update(from: authUser)

            // Then: fallback path triggers
            #expect(provider.currentUser.displayName == freshEmail)
        }
    }

    // MARK: - SupabaseScheduleRepository.fetchAll(memberOf:) (RLS member_select)

    @Suite(.serialized) struct JoinedSchedules {

        @Test("INT-J1. User B redeems A's invitation, then fetchAll(memberOf: B) returns A's schedule with rules and windows")
        func userBFetchesMemberOf_seesUserASchedule() async throws {
            // Given: A creates schedule X with one rule + one window, plus an invitation for X
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID(UUID())
            let windowStart = Date(timeIntervalSince1970: 1_777_734_000)
            var schedule = Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "INT-J1 \(UUID().uuidString.prefix(8))"
            )
            try schedule.addRule(
                id: AvailabilityRuleID(UUID()),
                weekday: .thursday,
                startTime: try TimeOfDay(hour: 9, minute: 0),
                endTime: try TimeOfDay(hour: 18, minute: 0)
            )
            try schedule.addWindow(
                id: AvailabilityWindowID(UUID()),
                start: windowStart,
                end: windowStart.addingTimeInterval(3600)
            )
            try await scheduleRepo.save(schedule)
            let createdAt = Date()
            let invitation = try Invitation(
                scheduleID: scheduleID,
                token: Self.uniqueToken(),
                expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: createdAt
            )
            try await invitationRepo.save(invitation)

            // When: B signs in, redeems, then asks for joined schedules
            let userBID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            _ = try await invitationRepo.redeem(token: invitation.token)
            let joined = try await scheduleRepo.fetchAll(memberOf: UserID(userBID.uuidString))

            // Then: B sees X with rules + windows intact (validates `member_select`
            // policy on schedules / availability_rules / availability_windows)
            let result = try #require(joined.first(where: { $0.id == scheduleID }))
            #expect(result.title == schedule.title)
            #expect(result.rules.count == 1)
            #expect(result.rules.first?.weekday == .thursday)
            #expect(result.windows.count == 1)
            #expect(result.windows.first?.start == windowStart)
        }

        @Test("INT-J2. User B with no memberships, fetchAll(memberOf: B) returns no schedules from this scenario")
        func userBNoMemberships_fetchesMemberOf_returnsEmpty() async throws {
            // Given: A owns a fresh schedule that B has NOT joined (no invitation, no redemption)
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let scheduleID = ScheduleID(UUID())
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "INT-J2 \(UUID().uuidString.prefix(8))"
            ))

            // When: B signs in (without any redemption flow), asks for joined
            let userBID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let joined = try await scheduleRepo.fetchAll(memberOf: UserID(userBID.uuidString))

            // Then: this freshly-created schedule must not appear in B's joined
            // list. Note: we cannot assert `joined.isEmpty` because earlier
            // tests in the same DB may have left B as a member of other
            // schedules — the contract being verified is that creating a
            // schedule alone (no invitation/redemption) gives B nothing.
            let leaked = joined.contains(where: { $0.id == scheduleID })
            if leaked {
                Issue.record("INT-J2 leak: joined contains the freshly-created schedule \(scheduleID). joined titles=\(joined.map(\.title))")
            }
            #expect(!leaked)
        }

        // MARK: - Helpers (mirror Redemption sub-suite's token generator)

        private static func uniqueToken() -> InvitationToken {
            let raw = UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .filter { InvitationToken.alphabetSet.contains($0) }
                .prefix(8)
                .padding(toLength: 8, withPad: "Z", startingAt: 0)
            return try! InvitationToken(raw)
        }
    }

    // MARK: - SupabaseBookingRepository (book_slot / cancel_booking RPCs + RLS)

    @Suite(.serialized) struct Bookings {

        private static let scheduleID = ScheduleID(IntegrationTestSupport.seededYogaScheduleID)
        private static let durationSeconds = 3600

        @Test("BINT1. User C (seeded member) books a future slot — RPC returns the booking row")
        func memberBooksFutureSlot_returnsBooking() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()

            // When
            let booking = try await repo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // Then
            #expect(booking.scheduleID == Self.scheduleID)
            #expect(booking.studentID.rawValue == IntegrationTestSupport.userCID.uuidString.lowercased())
            #expect(abs(booking.startsAt.timeIntervalSince(start)) < 1)
            #expect(abs(booking.endsAt.timeIntervalSince(end)) < 1)
            #expect(booking.durationSeconds == Self.durationSeconds)
        }

        @Test("BINT2. Booking same (schedule, starts_at) twice — second call throws .slotTaken")
        func sameSlotTwice_throwsSlotTaken() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            _ = try await repo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When / Then
            await #expect(throws: CreateBookingError.slotTaken) {
                _ = try await repo.create(
                    scheduleID: Self.scheduleID,
                    startsAt: start,
                    endsAt: end,
                    durationSeconds: Self.durationSeconds
                )
            }
        }

        @Test("BINT3. Owner (user A) books own schedule — throws .ownerCannotBook")
        func ownerBooksOwnSchedule_throwsOwnerCannotBook() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()

            // When / Then
            await #expect(throws: CreateBookingError.ownerCannotBook) {
                _ = try await repo.create(
                    scheduleID: Self.scheduleID,
                    startsAt: start,
                    endsAt: end,
                    durationSeconds: Self.durationSeconds
                )
            }
        }

        @Test("BINT4. Non-member (user B) books — throws .notMember")
        func nonMemberBooks_throwsNotMember() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()

            // When / Then
            await #expect(throws: CreateBookingError.notMember) {
                _ = try await repo.create(
                    scheduleID: Self.scheduleID,
                    startsAt: start,
                    endsAt: end,
                    durationSeconds: Self.durationSeconds
                )
            }
        }

        @Test("BINT5. After booking, fetchAll(scheduleID, studentID) returns the booking")
        func fetchAllAfterBooking_returnsTheBooking() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            let created = try await repo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When
            let bookings = try await repo.fetchAll(
                scheduleID: Self.scheduleID,
                studentID: UserID(IntegrationTestSupport.userCID.uuidString.lowercased())
            )

            // Then
            #expect(bookings.contains(where: { $0.id == created.id }))
        }

        @Test("BINT6. Member cancels own booking — fetchAll afterwards returns no row for that id")
        func memberCancelsOwnBooking_rowDisappears() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            let created = try await repo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When
            try await repo.cancel(id: created.id)

            // Then
            let bookings = try await repo.fetchAll(
                scheduleID: Self.scheduleID,
                studentID: UserID(IntegrationTestSupport.userCID.uuidString.lowercased())
            )
            #expect(!bookings.contains(where: { $0.id == created.id }))
        }

        @Test("BINT7. Non-owner (user B) cancels user C's booking — throws .notOwner; row remains")
        func nonOwnerCancels_throwsNotOwner() async throws {
            // Given: user C books
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            let created = try await repo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When: user B (no membership; never the booking owner) tries to cancel
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            await #expect(throws: CancelBookingError.notOwner) {
                try await repo.cancel(id: created.id)
            }

            // Then: row still readable by user C
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let bookings = try await repo.fetchAll(
                scheduleID: Self.scheduleID,
                studentID: UserID(IntegrationTestSupport.userCID.uuidString.lowercased())
            )
            #expect(bookings.contains(where: { $0.id == created.id }))
        }

        // MARK: - Helpers

        /// A fresh future timestamp at second precision, with a per-call
        /// random offset so parallel xcodebuild simulator clones running
        /// the same test name don't collide on the
        /// `UNIQUE(schedule_id, starts_at)` constraint of the seeded
        /// schedule. 7 days is the floor so we're never near "now".
        private static func freshFutureSlot() -> (start: Date, end: Date) {
            let entropySeconds = TimeInterval(abs(UUID().uuidString.hashValue) % (7 * 86_400))
            let baseEpoch = Date().timeIntervalSince1970.rounded(.down)
            let start = Date(
                timeIntervalSince1970: baseEpoch + 7 * 86_400 + entropySeconds
            )
            return (start, start.addingTimeInterval(TimeInterval(durationSeconds)))
        }

        // MARK: - Owner-side fetch (Slice 1.5)

        @Test("BINT8. Owner fetches bookings — sees C's booking with email AND seeded display name (Slice A)")
        func ownerFetchAll_returnsBookingsWithStudentEmailAndDisplayName() async throws {
            // Given: user C (whose profile is seeded as "Test Student C") books a slot
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            let created = try await repo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When: user A asks for all bookings on their schedule
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let result = try await repo.fetchAllForOwner(scheduleID: Self.scheduleID)

            // Then: owner view includes user C's booking with email AND
            // the displayName joined from user_profiles (Slice A).
            let ownerView = try #require(result.first(where: { $0.booking.id == created.id }))
            #expect(ownerView.studentEmail == IntegrationTestSupport.userCEmail)
            #expect(ownerView.studentDisplayName == "Test Student C")
            #expect(ownerView.booking.scheduleID == Self.scheduleID)
            #expect(abs(ownerView.booking.startsAt.timeIntervalSince(start)) < 1)
        }

        @Test("BINT8b. Owner sees a profile-less student's booking — displayName is nil, email surfaces (Slice A fallback)")
        func ownerFetchAll_profileLessStudent_returnsNilDisplayName() async throws {
            // Given: A creates a fresh schedule + invitation; a brand-new
            // user (no profile) signs up, redeems, books a slot. This
            // simulates the partial-signup state Slice A's UI fallback
            // is meant to handle.
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID()
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "BINT8b \(UUID().uuidString.prefix(8))"
            ))
            let invToken = try Self.bint8bToken()
            try await invitationRepo.save(try Invitation(
                scheduleID: scheduleID,
                token: invToken,
                expiresAt: Date().addingTimeInterval(60 * 60 * 24)
            ))

            let (freshEmail, _) = try await IntegrationTestSupport.signUpFreshUserConfirmed(
                prefix: "bint8b"
            )
            // Intentionally skip create_user_profile — partial signup state.

            _ = try await invitationRepo.redeem(token: invToken)
            let bookingRepo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            let created = try await bookingRepo.create(
                scheduleID: scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When: A fetches owner view
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let result = try await bookingRepo.fetchAllForOwner(scheduleID: scheduleID)

            // Then: that booking's displayName is nil; email is fresh user's email
            let ownerView = try #require(result.first(where: { $0.booking.id == created.id }))
            #expect(ownerView.studentDisplayName == nil)
            #expect(ownerView.studentEmail == freshEmail)
        }

        private static func bint8bToken() throws -> InvitationToken {
            let raw = UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .filter { InvitationToken.alphabetSet.contains($0) }
                .prefix(8)
                .padding(toLength: 8, withPad: "Z", startingAt: 0)
            return try InvitationToken(raw)
        }

        @Test("BINT9. Non-owner (user C) calls fetchAllForOwner — throws .notOwner")
        func nonOwnerFetchAll_throwsNotOwner() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let repo = SupabaseBookingRepository()

            // When / Then
            await #expect(throws: ListAllBookingsForOwnerError.notOwner) {
                _ = try await repo.fetchAllForOwner(scheduleID: Self.scheduleID)
            }
        }

        // MARK: - Cross-student visibility (Slice 2)

        /// As user A, create a fresh schedule and one valid invitation
        /// (which any non-owner can redeem multiple times — different
        /// users share the same token per Phase 3a `redeem_invitation`
        /// semantics). Used by BINT-V tests so each test owns its own
        /// schedule + can grant memberships without polluting the
        /// seeded `userCID` ↔ `seededYogaScheduleID` fixture.
        private static func seedFreshScheduleAndInvitation(
            titlePrefix: String
        ) async throws -> (ScheduleID, Invitation) {
            let userAID = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let scheduleRepo = SupabaseScheduleRepository()
            let invitationRepo = SupabaseInvitationRepository()
            let scheduleID = ScheduleID()
            try await scheduleRepo.save(Schedule(
                id: scheduleID,
                ownerID: UserID(userAID.uuidString),
                title: "\(titlePrefix) \(UUID().uuidString.prefix(8))"
            ))
            let createdAt = Date()
            let raw = UUID().uuidString
                .replacingOccurrences(of: "-", with: "")
                .uppercased()
                .filter { InvitationToken.alphabetSet.contains($0) }
                .prefix(8)
                .padding(toLength: 8, withPad: "Z", startingAt: 0)
            let invitation = try Invitation(
                scheduleID: scheduleID,
                token: try InvitationToken(raw),
                expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
                createdAt: createdAt
            )
            try await invitationRepo.save(invitation)
            return (scheduleID, invitation)
        }

        @Test("BINT-V1. Member sees other members' booking as sanitized BookedSlot")
        func memberSeesOthersBooking_returnsSanitized() async throws {
            // Given: A owns fresh schedule X; both B and C redeem the
            // same invitation and become members of X.
            let (scheduleID, invitation) = try await Self.seedFreshScheduleAndInvitation(
                titlePrefix: "BINT-V1"
            )
            let invitationRepo = SupabaseInvitationRepository()
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            _ = try await invitationRepo.redeem(token: invitation.token)
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            _ = try await invitationRepo.redeem(token: invitation.token)

            // C books a future slot on X.
            let bookingRepo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            _ = try await bookingRepo.create(
                scheduleID: scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When: B asks for others' bookings on X.
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let result = try await bookingRepo.fetchOthersBookings(scheduleID: scheduleID)

            // Then: exactly the slot C booked surfaces; BookedSlot's type
            // shape inherently has no booking_id / student_id / email,
            // and the RPC's RETURN TABLE signature (verified at migration
            // time) is the security boundary that guarantees nothing else
            // can leak through this path.
            let visible = try #require(result.first(where: { abs($0.startsAt.timeIntervalSince(start)) < 1 }))
            #expect(abs(visible.endsAt.timeIntervalSince(end)) < 1)
            #expect(visible.durationSeconds == Self.durationSeconds)
        }

        @Test("BINT-V2. Caller's own booking is filtered out of fetchOthersBookings")
        func callerOwnBooking_filteredOut() async throws {
            // Given: C is a member (seeded) of the seeded schedule and
            // books a slot on it.
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userCEmail)
            let bookingRepo = SupabaseBookingRepository()
            let (start, end) = Self.freshFutureSlot()
            let mine = try await bookingRepo.create(
                scheduleID: Self.scheduleID,
                startsAt: start,
                endsAt: end,
                durationSeconds: Self.durationSeconds
            )

            // When: C asks for others' bookings on the same schedule.
            let result = try await bookingRepo.fetchOthersBookings(scheduleID: Self.scheduleID)

            // Then: C's own booking is not in the result (RPC's
            // `student_id <> auth.uid()` filter).
            #expect(!result.contains(where: { abs($0.startsAt.timeIntervalSince(mine.startsAt)) < 1 }))
        }

        @Test("BINT-V3. Non-member calls fetchOthersBookings — throws .notMember")
        func nonMemberFetchOthers_throwsNotMember() async throws {
            // Given: A owns a fresh schedule X (no invitations redeemed
            // by B → B is not a member of X).
            let (scheduleID, _) = try await Self.seedFreshScheduleAndInvitation(
                titlePrefix: "BINT-V3"
            )
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userBEmail)
            let bookingRepo = SupabaseBookingRepository()

            // When / Then
            await #expect(throws: ListOthersBookingsError.notMember) {
                _ = try await bookingRepo.fetchOthersBookings(scheduleID: scheduleID)
            }
        }

        @Test("BINT-V4. Owner (non-member of own schedule) calls fetchOthersBookings — throws .notMember")
        func ownerFetchOthers_throwsNotMember() async throws {
            // Given: A is the owner of the seeded schedule but holds no
            // membership row on it (owners are not members in this app
            // model). Owners are expected to use fetchAllForOwner — the
            // member-only RPC pre-emptively rejects them.
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let bookingRepo = SupabaseBookingRepository()

            // When / Then
            await #expect(throws: ListOthersBookingsError.notMember) {
                _ = try await bookingRepo.fetchOthersBookings(scheduleID: Self.scheduleID)
            }
        }
    }

    // MARK: - SupabaseUserProfileRepository (Phase 4 Slice A)

    @Suite(.serialized) struct UserProfiles {

        /// Sign up a brand-new confirmed user, leaving them signed-in.
        /// Used by tests that need a profile-less account to exercise
        /// the fresh-create path or the partial-signup fallback.
        /// (Slice C: `enable_confirmations = true` means plain signUp
        /// yields no session — confirmation goes through Mailpit OTP.)
        private static func signUpFreshUser(prefix: String) async throws -> (email: String, userID: UUID) {
            try await IntegrationTestSupport.signUpFreshUserConfirmed(prefix: prefix)
        }

        @Test("UINT1. Fresh signed-up user creates own profile — returns UserProfile, DB row exists")
        func freshUserCreatesOwnProfile_returnsProfile() async throws {
            // Given: brand-new auth user, no profile yet
            let (_, userID) = try await Self.signUpFreshUser(prefix: "uint1")
            let repo = SupabaseUserProfileRepository()

            // When
            let profile = try await repo.create(displayName: "小明")

            // Then
            #expect(profile.userID.rawValue == userID.uuidString.lowercased())
            #expect(profile.displayName == "小明")

            // Confirm it's actually fetchable now (and via the same path
            // SupabaseAuthCurrentUserProvider will use post-sign-in)
            let fetched = try await repo.fetch(
                userID: UserID(userID.uuidString.lowercased())
            )
            #expect(fetched?.displayName == "小明")
        }

        @Test("UINT2. Seed user with backfilled profile calls create — throws .alreadyExists")
        func seedUserCreateAgain_throwsAlreadyExists() async throws {
            // Given: seed user A's profile already exists (seed.sql)
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseUserProfileRepository()

            // When / Then
            await #expect(throws: UserProfileError.alreadyExists) {
                _ = try await repo.create(displayName: "Anything")
            }
        }

        @Test("UINT3. Create with 51-char displayName — throws .invalidDisplayName")
        func createWithTooLongDisplayName_throwsInvalidDisplayName() async throws {
            // Given: fresh user so we don't bounce off ALREADY_EXISTS first
            _ = try await Self.signUpFreshUser(prefix: "uint3")
            let repo = SupabaseUserProfileRepository()
            let fiftyOne = String(repeating: "a", count: 51)

            // When / Then
            await #expect(throws: UserProfileError.invalidDisplayName) {
                _ = try await repo.create(displayName: fiftyOne)
            }
        }

        @Test("UINT4. User A fetches user B's profile — RLS hides it (returns nil)")
        func userAFetchesUserBProfile_rlsReturnsNil() async throws {
            // Given: A signed in
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseUserProfileRepository()

            // When
            let result = try await repo.fetch(
                userID: UserID(IntegrationTestSupport.userBID.uuidString.lowercased())
            )

            // Then
            #expect(result == nil)
        }

        @Test("UINT5. User A fetches own profile — returns UserProfile (self_select)")
        func userAFetchesOwnProfile_returnsProfile() async throws {
            // Given
            _ = try await IntegrationTestSupport.signIn(email: IntegrationTestSupport.userAEmail)
            let repo = SupabaseUserProfileRepository()

            // When
            let result = try await repo.fetch(
                userID: UserID(IntegrationTestSupport.userAID.uuidString.lowercased())
            )

            // Then
            #expect(result?.displayName == "Test Teacher A")
            #expect(result?.userID.rawValue == IntegrationTestSupport.userAID.uuidString.lowercased())
        }

        @Test("PINT1. Fresh user with a profile updates displayName — row overwritten")
        func updateExistingProfile_overwritesDisplayName() async throws {
            // Given: fresh user that already has a profile
            let (_, userID) = try await Self.signUpFreshUser(prefix: "pint1")
            let repo = SupabaseUserProfileRepository()
            _ = try await repo.create(displayName: "初名")

            // When
            let updated = try await repo.update(displayName: "新名")

            // Then
            #expect(updated.displayName == "新名")
            #expect(updated.userID.rawValue == userID.uuidString.lowercased())
            let fetched = try await repo.fetch(
                userID: UserID(userID.uuidString.lowercased())
            )
            #expect(fetched?.displayName == "新名")
        }

        @Test("PINT2. Fresh user with no profile updates — upsert creates the row")
        func updateWithNoProfile_upsertCreatesRow() async throws {
            // Given: fresh user, profile creation skipped (legacy / partial signup)
            let (_, userID) = try await Self.signUpFreshUser(prefix: "pint2")
            let repo = SupabaseUserProfileRepository()

            // When
            let updated = try await repo.update(displayName: "初設")

            // Then
            #expect(updated.displayName == "初設")
            let fetched = try await repo.fetch(
                userID: UserID(userID.uuidString.lowercased())
            )
            #expect(fetched?.displayName == "初設")
        }

        @Test("PINT3. Update with 51-char displayName — throws .invalidDisplayName")
        func updateWithTooLongDisplayName_throwsInvalidDisplayName() async throws {
            // Given
            _ = try await Self.signUpFreshUser(prefix: "pint3")
            let repo = SupabaseUserProfileRepository()
            let fiftyOne = String(repeating: "a", count: 51)

            // When / Then
            await #expect(throws: UserProfileError.invalidDisplayName) {
                _ = try await repo.update(displayName: fiftyOne)
            }
        }
    }

    @Suite(.serialized) struct Accounts {

        /// Sign up a brand-new confirmed user, leaving them signed-in.
        /// Mirrors the UserProfiles helper — kept local since private
        /// statics aren't shared across sub-suites.
        private static func signUpFreshUser(prefix: String) async throws -> (email: String, userID: UUID) {
            try await IntegrationTestSupport.signUpFreshUserConfirmed(prefix: prefix)
        }

        @Test("AINT1. Delete account that owns a profile + schedule — succeeds; re-signin fails (cascade + auth.users gone)")
        func deleteAccountWithData_succeedsAndReSignInFails() async throws {
            // Given: a fresh user with a profile and an owned schedule.
            // The owned schedule proves the owner_id FK is ON DELETE
            // CASCADE — a RESTRICT FK would make delete_account throw.
            let (email, userID) = try await Self.signUpFreshUser(prefix: "aint1")
            let profileRepo = SupabaseUserProfileRepository()
            _ = try await profileRepo.create(displayName: "待刪")
            let scheduleRepo = SupabaseScheduleRepository()
            let schedule = Schedule(
                id: ScheduleID(UUID()),
                ownerID: UserID(userID.uuidString),
                title: "To be cascaded \(UUID().uuidString.prefix(8))"
            )
            try await scheduleRepo.save(schedule)

            // When
            let accountRepo = SupabaseAccountRepository()
            try await accountRepo.deleteAccount()

            // Then: the auth.users row (and all cascaded data) is gone —
            // signing back in with the same credentials must fail.
            await #expect(throws: (any Error).self) {
                _ = try await SupabaseClientProvider.auth.signIn(
                    email: email,
                    password: IntegrationTestSupport.testPassword
                )
            }
        }

        @Test("AINT2. delete_account without a session — fails (auth gate)")
        func deleteAccountWithoutSession_fails() async throws {
            // Given: no active session
            try? await SupabaseClientProvider.auth.signOut()
            let accountRepo = SupabaseAccountRepository()

            // When / Then: the RPC requires auth.uid(); no session → fails
            await #expect(throws: DeleteAccountError.self) {
                try await accountRepo.deleteAccount()
            }
        }
    }

    // MARK: - Email verification (Slice C — enable_confirmations = true)

    @Suite(.serialized) struct EmailVerification {

        /// Sign up a fresh user WITHOUT confirming, returning the email.
        private static func signUpUnconfirmed(prefix: String) async throws -> String {
            let email = "\(prefix)-\(UUID().uuidString.prefix(8))@example.com".lowercased()
            try? await SupabaseClientProvider.auth.signOut()
            _ = try await SupabaseClientProvider.auth.signUp(
                email: email,
                password: IntegrationTestSupport.testPassword
            )
            return email
        }

        @Test("CINT1. signUp 無 session → Mailpit 取 6 碼 → verifySignUpOTP → session 有效")
        func signUpThenVerifyOTP_yieldsValidSession() async throws {
            // Given: fresh sign-up; confirmations on means no session yet
            let email = try await Self.signUpUnconfirmed(prefix: "cint1")
            await #expect(throws: (any Error).self, "signUp must not create a session") {
                _ = try await SupabaseClientProvider.auth.session
            }

            // When: pull the OTP from Mailpit and verify via the adapter
            let otp = try await MailpitClient.waitForLatestOTP(to: email)
            let client = SupabaseAuthSessionClient()
            try await client.verifySignUpOTP(email: email, token: otp)

            // Then: a session now exists for that user
            let session = try await SupabaseClientProvider.auth.session
            #expect(session.user.email == email)
        }

        @Test("CINT2. 未驗證帳號 signIn → .emailNotConfirmed（釘住 400 + msg 字串比對）")
        func signInBeforeConfirmation_throwsEmailNotConfirmed() async throws {
            // Given
            let email = try await Self.signUpUnconfirmed(prefix: "cint2")
            let client = SupabaseAuthSessionClient()

            // When / Then
            await #expect(throws: AuthSignInError.emailNotConfirmed) {
                try await client.signIn(
                    email: email,
                    password: IntegrationTestSupport.testPassword
                )
            }
        }

        @Test("CINT3. 錯誤驗證碼 → .invalidOrExpiredCode")
        func verifyWithWrongCode_throwsInvalidOrExpiredCode() async throws {
            // Given
            let email = try await Self.signUpUnconfirmed(prefix: "cint3")
            let correctOTP = try await MailpitClient.waitForLatestOTP(to: email)
            let wrongCode = correctOTP == "000000" ? "000001" : "000000"
            let client = SupabaseAuthSessionClient()

            // When / Then
            await #expect(throws: VerifyOTPClientError.invalidOrExpiredCode) {
                try await client.verifySignUpOTP(email: email, token: wrongCode)
            }
        }

        @Test("CINT4. resendSignUpConfirmation → 該信箱信件數增加")
        func resendConfirmation_deliversSecondEmail() async throws {
            // Given: one confirmation email already delivered
            let email = try await Self.signUpUnconfirmed(prefix: "cint4")
            _ = try await MailpitClient.waitForMessageIDs(to: email, atLeast: 1)

            // When (local max_frequency = "1s" — wait it out first)
            try await Task.sleep(for: .seconds(1.5))
            let client = SupabaseAuthSessionClient()
            try await client.resendSignUpConfirmation(email: email)

            // Then
            let ids = try await MailpitClient.waitForMessageIDs(to: email, atLeast: 2)
            #expect(ids.count == 2)
        }
    }

    // MARK: - Password reset (Slice D — recovery OTP flow)

    @Suite(.serialized) struct PasswordReset {

        /// Fresh confirmed user (1 confirmation email in the mailbox),
        /// signed out, with a recovery email requested — returns the
        /// recovery OTP. Waits out `max_frequency = "1s"` between the
        /// confirmation and recovery sends.
        private static func requestRecoveryForFreshUser(
            prefix: String
        ) async throws -> (email: String, otp: String) {
            let (email, _) = try await IntegrationTestSupport.signUpFreshUserConfirmed(prefix: prefix)
            await IntegrationTestSupport.signOut()
            try await Task.sleep(for: .seconds(1.5))
            let client = SupabaseAuthPasswordResetClient()
            try await client.requestPasswordReset(email: email)
            // Mailbox: [confirmation]; wait for the recovery mail to
            // land, then take the newest (index 0 = recovery).
            _ = try await MailpitClient.waitForMessageIDs(to: email, atLeast: 2)
            let otp = try await MailpitClient.waitForLatestOTP(to: email)
            return (email, otp)
        }

        @Test("DINT1. 重設後新密碼可登入、舊密碼失敗（happy path）")
        func fullResetFlow_newPasswordWorks_oldPasswordFails() async throws {
            // Given
            let (email, otp) = try await Self.requestRecoveryForFreshUser(prefix: "dint1")
            let client = SupabaseAuthPasswordResetClient()

            // When: verify OTP (yields session) then set the new password
            try await client.verifyRecoveryOTP(email: email, token: otp)
            try await client.updatePassword("newpassword456")

            // Then: new password signs in; the old one is rejected
            await IntegrationTestSupport.signOut()
            let session = try await SupabaseClientProvider.auth.signIn(
                email: email,
                password: "newpassword456"
            )
            #expect(session.user.email == email)

            try? await SupabaseClientProvider.auth.signOut()
            let sessionClient = SupabaseAuthSessionClient()
            await #expect(throws: AuthSignInError.invalidCredentials) {
                try await sessionClient.signIn(
                    email: email,
                    password: IntegrationTestSupport.testPassword
                )
            }
        }

        @Test("DINT2. 錯誤 recovery 碼 → .invalidOrExpiredCode")
        func verifyWithWrongRecoveryCode_throwsInvalidOrExpiredCode() async throws {
            // Given
            let (email, otp) = try await Self.requestRecoveryForFreshUser(prefix: "dint2")
            let wrongCode = otp == "000000" ? "000001" : "000000"
            let client = SupabaseAuthPasswordResetClient()

            // When / Then
            await #expect(throws: VerifyOTPClientError.invalidOrExpiredCode) {
                try await client.verifyRecoveryOTP(email: email, token: wrongCode)
            }
        }

        @Test("DINT3. 新密碼與舊密碼相同 → .samePassword（釘住 422 映射）")
        func updateToSamePassword_throwsSamePassword() async throws {
            // Given: recovery session established
            let (email, otp) = try await Self.requestRecoveryForFreshUser(prefix: "dint3")
            let client = SupabaseAuthPasswordResetClient()
            try await client.verifyRecoveryOTP(email: email, token: otp)

            // When / Then
            await #expect(throws: UpdatePasswordClientError.samePassword) {
                try await client.updatePassword(IntegrationTestSupport.testPassword)
            }
        }
    }
}

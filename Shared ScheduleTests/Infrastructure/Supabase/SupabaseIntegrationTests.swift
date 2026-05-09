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
    }
}

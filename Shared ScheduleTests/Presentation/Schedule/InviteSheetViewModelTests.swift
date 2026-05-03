import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct InviteSheetViewModelTests {

    private let scheduleID = ScheduleID(UUID())
    private let teacherID = UserID("teacher-001")

    private func makeSchedule() -> Schedule {
        Schedule(id: scheduleID, ownerID: teacherID, title: "Yoga")
    }

    private func makeInvitation(suffix: String, createdAt: Date = Date()) throws -> Invitation {
        try Invitation(
            scheduleID: scheduleID,
            token: try InvitationToken(suffix.padding(toLength: 8, withPad: "0", startingAt: 0)),
            expiresAt: createdAt.addingTimeInterval(60 * 60 * 24 * 7),
            createdAt: createdAt
        )
    }

    // MARK: - V1

    @Test("onAppear，repo 為空，invitations == []")
    func onAppear_emptyRepo_invitationsIsEmpty() async {
        // Given
        let listFake = FakeListInvitationsUseCase()
        listFake.resultToReturn = []
        let createFake = FakeCreateInvitationUseCase()
        let vm = InviteSheetViewModel(
            schedule: makeSchedule(),
            createInvitationUseCase: createFake,
            listInvitationsUseCase: listFake
        )

        // When
        await vm.onAppear()

        // Then
        #expect(vm.invitations.isEmpty)
        #expect(vm.loadError == nil)
    }

    // MARK: - V2

    @Test("onAppear，repo 有 2 筆，invitations.count == 2")
    func onAppear_twoInvitations_populatesList() async throws {
        // Given
        let a = try makeInvitation(suffix: "AAAA1234")
        let b = try makeInvitation(suffix: "BBBB5678")
        let listFake = FakeListInvitationsUseCase()
        listFake.resultToReturn = [a, b]
        let createFake = FakeCreateInvitationUseCase()
        let vm = InviteSheetViewModel(
            schedule: makeSchedule(),
            createInvitationUseCase: createFake,
            listInvitationsUseCase: listFake
        )

        // When
        await vm.onAppear()

        // Then
        #expect(vm.invitations.count == 2)
        #expect(listFake.lastScheduleID == scheduleID)
    }

    // MARK: - V3

    @Test("didTapGenerate 成功，新 invitation 出現在列表頂端")
    func didTapGenerate_success_prependsToList() async throws {
        // Given
        let existing = try makeInvitation(suffix: "AAAA1234")
        let listFake = FakeListInvitationsUseCase()
        listFake.resultToReturn = [existing]
        let createFake = FakeCreateInvitationUseCase()
        let newInvitation = try makeInvitation(suffix: "NEW12345")
        createFake.resultToReturn = newInvitation
        let vm = InviteSheetViewModel(
            schedule: makeSchedule(),
            createInvitationUseCase: createFake,
            listInvitationsUseCase: listFake
        )
        await vm.onAppear()

        // When
        await vm.didTapGenerate()

        // Then
        #expect(vm.invitations.first == newInvitation)
        #expect(vm.invitations.count == 2)
        #expect(vm.isGenerating == false)
        #expect(vm.inlineError == nil)
        #expect(createFake.callCount == 1)
        #expect(createFake.lastScheduleID == scheduleID)
    }

    // MARK: - V4

    @Test("didTapGenerate 失敗，inlineError 設定、列表不變")
    func didTapGenerate_failure_setsInlineError() async throws {
        // Given
        let existing = try makeInvitation(suffix: "AAAA1234")
        let listFake = FakeListInvitationsUseCase()
        listFake.resultToReturn = [existing]
        let createFake = FakeCreateInvitationUseCase()
        createFake.errorToThrow = .persistenceFailure
        let vm = InviteSheetViewModel(
            schedule: makeSchedule(),
            createInvitationUseCase: createFake,
            listInvitationsUseCase: listFake
        )
        await vm.onAppear()

        // When
        await vm.didTapGenerate()

        // Then
        #expect(vm.invitations == [existing])  // unchanged
        #expect(vm.inlineError != nil)
        #expect(vm.isGenerating == false)
    }
}

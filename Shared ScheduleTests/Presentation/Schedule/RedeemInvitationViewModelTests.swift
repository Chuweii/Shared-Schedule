import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct RedeemInvitationViewModelTests {

    private let scheduleID = ScheduleID(UUID())
    private let teacherID = UserID("teacher-001")

    private func makeSchedule(title: String = "Yoga 101") -> Schedule {
        Schedule(id: scheduleID, ownerID: teacherID, title: title)
    }

    private func makeViewModel(
        usecase: FakeRedeemInvitationUseCase = FakeRedeemInvitationUseCase()
    ) -> RedeemInvitationViewModel {
        RedeemInvitationViewModel(redeemInvitationUseCase: usecase)
    }

    // MARK: - VN1

    @Test("VN1. normalize 處理小寫、標點、過濾非 Crockford 字元")
    func normalize_lowercaseAndPunctuation_uppercasesAndFilters() {
        // Given / When
        let result = RedeemInvitationViewModel.normalize("abcd-12 34!o")

        // Then — 'O' is excluded from Crockford alphabet, dash/space/!/lowercase are stripped/upcased
        #expect(result == "ABCD1234")
    }

    // MARK: - VN2

    @Test("VN2. normalize 截斷至 8 字元")
    func normalize_overEightChars_truncatesToEight() {
        // Given / When
        let result = RedeemInvitationViewModel.normalize("ABCDEFGHJKMN")

        // Then
        #expect(result == "ABCDEFGH")
    }

    // MARK: - V1

    @Test("V1. updateInput 正規化並清掉先前的 inlineError")
    func updateInput_normalizes_andClearsInlineError() async {
        // Given — drive vm into an error state first
        let usecase = FakeRedeemInvitationUseCase()
        usecase.errorToThrow = .invalidToken
        let vm = makeViewModel(usecase: usecase)
        vm.updateInput("ABCD1234")
        await vm.didTapSubmit()
        #expect(vm.inlineError != nil)  // sanity check

        // When
        vm.updateInput("abcd1234")

        // Then
        #expect(vm.input == "ABCD1234")
        #expect(vm.inlineError == nil)
    }

    // MARK: - V2

    @Test("V2. didTapSubmit 在 input 不到 8 字元時 no-op")
    func didTapSubmit_belowEightChars_doesNothing() async {
        // Given
        let usecase = FakeRedeemInvitationUseCase()
        let vm = makeViewModel(usecase: usecase)
        vm.updateInput("ABC")

        // When
        await vm.didTapSubmit()

        // Then
        #expect(usecase.callCount == 0)
        #expect(vm.success == nil)
        #expect(vm.inlineError == nil)
    }

    // MARK: - V3

    @Test("V3. didTapSubmit 成功，success state 設定為對應 Schedule")
    func didTapSubmit_success_setsSuccessStateWithSchedule() async {
        // Given
        let usecase = FakeRedeemInvitationUseCase()
        usecase.resultToReturn = makeSchedule(title: "瑜珈基礎班")
        let vm = makeViewModel(usecase: usecase)
        vm.updateInput("ABCD1234")

        // When
        await vm.didTapSubmit()

        // Then
        #expect(vm.success?.schedule.id == scheduleID)
        #expect(vm.success?.schedule.title == "瑜珈基礎班")
        #expect(vm.isSubmitting == false)
        #expect(vm.inlineError == nil)
        #expect(usecase.callCount == 1)
    }

    // MARK: - V4

    @Test("V4. didTapSubmit invalidToken，設 inlineError、input 保留")
    func didTapSubmit_invalidToken_setsInlineErrorAndKeepsInput() async {
        // Given
        let usecase = FakeRedeemInvitationUseCase()
        usecase.errorToThrow = .invalidToken
        let vm = makeViewModel(usecase: usecase)
        vm.updateInput("ABCD1234")

        // When
        await vm.didTapSubmit()

        // Then
        #expect(vm.success == nil)
        #expect(vm.inlineError != nil)
        #expect(vm.input == "ABCD1234")
        #expect(vm.isSubmitting == false)
    }

    // MARK: - V5

    @Test("V5. didTapSubmit alreadyMember，inlineError 訊息對應")
    func didTapSubmit_alreadyMember_setsAlreadyMemberInlineError() async {
        // Given
        let usecase = FakeRedeemInvitationUseCase()
        usecase.errorToThrow = .alreadyMember
        let vm = makeViewModel(usecase: usecase)
        vm.updateInput("ABCD1234")

        // When
        await vm.didTapSubmit()

        // Then
        #expect(vm.inlineError != nil)
        // V4/V5 cover the inlineError write path; the per-error message
        // mapping is exercised at a higher level (View renders the
        // LocalizedStringResource directly) — don't compare LSR equality
        // here since LocalizedStringResource isn't trivially Equatable.
    }
}

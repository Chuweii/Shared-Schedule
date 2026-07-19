import Testing
import Foundation
@testable import Shared_Schedule

struct ForgotPasswordViewModelTests {

    @MainActor
    private final class CompletionSpy {
        private(set) var count = 0
        func call() { count += 1 }
    }

    @MainActor
    private func makeSUT() -> (
        vm: ForgotPasswordViewModel,
        fakeRequest: FakeRequestPasswordResetUseCase,
        fakeVerify: FakeVerifyRecoveryOTPUseCase,
        fakeUpdate: FakeUpdatePasswordUseCase,
        completion: CompletionSpy
    ) {
        let fakeRequest = FakeRequestPasswordResetUseCase()
        let fakeVerify = FakeVerifyRecoveryOTPUseCase()
        let fakeUpdate = FakeUpdatePasswordUseCase()
        let completion = CompletionSpy()
        let vm = ForgotPasswordViewModel(
            requestPasswordResetUseCase: fakeRequest,
            verifyRecoveryOTPUseCase: fakeVerify,
            updatePasswordUseCase: fakeUpdate,
            onComplete: { completion.call() }
        )
        return (vm, fakeRequest, fakeVerify, fakeUpdate, completion)
    }

    @MainActor
    @Test("FVM1. sendCode email 有效 + fake 成功 → step .enterCode、error nil、冷卻 60 秒")
    func sendCode_validEmail_advancesToEnterCode() async {
        // Given
        let (vm, fakeRequest, _, _, _) = makeSUT()
        vm.email = "x@y.com"

        // When
        await vm.sendCode()

        // Then
        #expect(vm.step == .enterCode)
        #expect(vm.error == nil)
        #expect(fakeRequest.callCount == 1)
        #expect(fakeRequest.lastEmail == "x@y.com")
        #expect(vm.resendSecondsRemaining == 60)
    }

    @MainActor
    @Test("FVM2. sendCode email 留空 → error .emptyEmail、step 不變、useCase 未呼叫")
    func sendCode_emptyEmail_failsPreflight() async {
        // Given
        let (vm, fakeRequest, _, _, _) = makeSUT()
        vm.email = "   "

        // When
        await vm.sendCode()

        // Then
        #expect(vm.error == .emptyEmail)
        #expect(vm.step == .enterEmail)
        #expect(fakeRequest.callCount == 0)
    }

    @MainActor
    @Test("FVM3. sendCode fake 拋 .rateLimited → error .rateLimited、step 不變")
    func sendCode_rateLimited_staysOnEnterEmail() async {
        // Given
        let (vm, fakeRequest, _, _, _) = makeSUT()
        fakeRequest.errorToThrow = .rateLimited
        vm.email = "x@y.com"

        // When
        await vm.sendCode()

        // Then
        #expect(vm.error == .rateLimited)
        #expect(vm.step == .enterEmail)
    }

    @MainActor
    @Test("FVM4. verifyCode 正確 6 碼 + fake 成功 → step .newPassword、error nil")
    func verifyCode_validCode_advancesToNewPassword() async {
        // Given
        let (vm, _, fakeVerify, _, _) = makeSUT()
        vm.email = "x@y.com"
        vm.step = .enterCode
        vm.code = "123456"

        // When
        await vm.verifyCode()

        // Then
        #expect(vm.step == .newPassword)
        #expect(vm.error == nil)
        #expect(fakeVerify.callCount == 1)
        #expect(fakeVerify.lastCode == "123456")
    }

    @MainActor
    @Test("FVM5. verifyCode code 留空 → error .emptyCode、useCase 未呼叫")
    func verifyCode_emptyCode_failsPreflight() async {
        // Given
        let (vm, _, fakeVerify, _, _) = makeSUT()
        vm.step = .enterCode
        vm.code = "   "

        // When
        await vm.verifyCode()

        // Then
        #expect(vm.error == .emptyCode)
        #expect(vm.step == .enterCode)
        #expect(fakeVerify.callCount == 0)
    }

    @MainActor
    @Test("FVM6. verifyCode fake 拋 .invalidOrExpiredCode → error 設定、step 停在 .enterCode")
    func verifyCode_invalidCode_staysOnEnterCode() async {
        // Given
        let (vm, _, fakeVerify, _, _) = makeSUT()
        fakeVerify.errorToThrow = .invalidOrExpiredCode
        vm.step = .enterCode
        vm.code = "123456"

        // When
        await vm.verifyCode()

        // Then
        #expect(vm.error == .invalidOrExpiredCode)
        #expect(vm.step == .enterCode)
    }

    @MainActor
    @Test("FVM7. submitNewPassword 有效 + fake 成功 → step .done（成功畫面）、onComplete 未呼叫")
    func submitNewPassword_success_showsDoneWithoutCompleting() async {
        // Given
        let (vm, _, _, fakeUpdate, completion) = makeSUT()
        vm.step = .newPassword
        vm.newPassword = "newpassword456"

        // When
        await vm.submitNewPassword()

        // Then — stays on the success screen until the user taps 開始使用
        #expect(vm.step == .done)
        #expect(vm.error == nil)
        #expect(fakeUpdate.callCount == 1)
        #expect(completion.count == 0)
    }

    @MainActor
    @Test("FVM8. submitNewPassword fake 拋 .samePassword → error 設定、step 停在 .newPassword、onComplete 未呼叫")
    func submitNewPassword_samePassword_staysOnNewPassword() async {
        // Given
        let (vm, _, _, fakeUpdate, completion) = makeSUT()
        fakeUpdate.errorToThrow = .samePassword
        vm.step = .newPassword
        vm.newPassword = "newpassword456"

        // When
        await vm.submitNewPassword()

        // Then
        #expect(vm.error == .samePassword)
        #expect(vm.step == .newPassword)
        #expect(completion.count == 0)
    }

    @MainActor
    @Test("FVM9. resendCode 冷卻中不呼叫；冷卻 0 時呼叫並重啟冷卻、step 不變")
    func resendCode_respectsCooldownAndResends() async {
        // Given: cooling down
        let (vm, fakeRequest, _, _, _) = makeSUT()
        vm.email = "x@y.com"
        vm.step = .enterCode
        vm.resendSecondsRemaining = 30

        // When
        await vm.resendCode()

        // Then
        #expect(fakeRequest.callCount == 0)

        // Given: cooldown elapsed
        vm.resendSecondsRemaining = 0

        // When
        await vm.resendCode()

        // Then
        #expect(fakeRequest.callCount == 1)
        #expect(vm.resendSecondsRemaining == 60)
        #expect(vm.step == .enterCode)
    }

    @MainActor
    @Test("FVM10. step .done 時 finish() → onComplete 呼叫 1 次")
    func finish_onDoneStep_callsOnComplete() {
        // Given
        let (vm, _, _, _, completion) = makeSUT()
        vm.step = .done

        // When
        vm.finish()

        // Then
        #expect(completion.count == 1)
    }
}

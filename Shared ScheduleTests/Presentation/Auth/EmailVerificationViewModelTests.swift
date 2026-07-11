import Testing
import Foundation
@testable import Shared_Schedule

struct EmailVerificationViewModelTests {

    private static let userID = UserID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

    @MainActor
    private func makeSUT(displayName: String? = "小明") -> (
        vm: EmailVerificationViewModel,
        fakeVerify: FakeVerifyEmailOTPUseCase,
        fakeResend: FakeResendVerificationCodeUseCase,
        fakeProvider: FakeCurrentUserProvider
    ) {
        let fakeVerify = FakeVerifyEmailOTPUseCase()
        let fakeResend = FakeResendVerificationCodeUseCase()
        let fakeProvider = FakeCurrentUserProvider(
            user: User(id: Self.userID, displayName: "原名")
        )
        let vm = EmailVerificationViewModel(
            email: "x@y.com",
            displayName: displayName,
            verifyEmailOTPUseCase: fakeVerify,
            resendVerificationCodeUseCase: fakeResend,
            currentUserProvider: fakeProvider
        )
        return (vm, fakeVerify, fakeResend, fakeProvider)
    }

    @MainActor
    @Test("EVM1. 正確 6 碼 + displayName → error nil、useCase called、updateCachedDisplayName 帶 displayName")
    func verify_validCodeWithDisplayName_verifiesAndUpdatesCache() async {
        // Given
        let (vm, fakeVerify, _, fakeProvider) = makeSUT()
        vm.code = "123456"

        // When
        await vm.verify()

        // Then
        #expect(vm.error == nil)
        #expect(fakeVerify.callCount == 1)
        #expect(fakeVerify.lastEmail == "x@y.com")
        #expect(fakeVerify.lastCode == "123456")
        #expect(fakeVerify.lastDisplayName == "小明")
        #expect(fakeProvider.currentUser.displayName == "小明")
    }

    @MainActor
    @Test("EVM2. code 留空 → error == .emptyCode、useCase 未呼叫")
    func verify_emptyCode_failsPreflight() async {
        // Given
        let (vm, fakeVerify, _, _) = makeSUT()
        vm.code = "   "

        // When
        await vm.verify()

        // Then
        #expect(vm.error == .emptyCode)
        #expect(fakeVerify.callCount == 0)
    }

    @MainActor
    @Test("EVM3. fakeVerify 拋 .invalidCodeFormat → error == .invalidCodeFormat")
    func verify_useCaseInvalidCodeFormat_setsError() async {
        // Given
        let (vm, fakeVerify, _, _) = makeSUT()
        fakeVerify.errorToThrow = .invalidCodeFormat
        vm.code = "123456"

        // When
        await vm.verify()

        // Then
        #expect(vm.error == .invalidCodeFormat)
    }

    @MainActor
    @Test("EVM4. fakeVerify 拋 .invalidOrExpiredCode → error == .invalidOrExpiredCode")
    func verify_useCaseInvalidOrExpiredCode_setsError() async {
        // Given
        let (vm, fakeVerify, _, _) = makeSUT()
        fakeVerify.errorToThrow = .invalidOrExpiredCode
        vm.code = "123456"

        // When
        await vm.verify()

        // Then
        #expect(vm.error == .invalidOrExpiredCode)
    }

    @MainActor
    @Test("EVM5. fakeVerify 拋 .rateLimited → error == .rateLimited")
    func verify_useCaseRateLimited_setsError() async {
        // Given
        let (vm, fakeVerify, _, _) = makeSUT()
        fakeVerify.errorToThrow = .rateLimited
        vm.code = "123456"

        // When
        await vm.verify()

        // Then
        #expect(vm.error == .rateLimited)
    }

    @MainActor
    @Test("EVM6. resend（冷卻 0）→ useCase called 1 次、冷卻設為 60 秒")
    func resend_notCoolingDown_callsUseCaseAndStartsCooldown() async {
        // Given
        let (vm, _, fakeResend, _) = makeSUT()

        // When
        await vm.resend()

        // Then
        #expect(fakeResend.callCount == 1)
        #expect(fakeResend.lastEmail == "x@y.com")
        #expect(vm.resendSecondsRemaining == 60)
    }

    @MainActor
    @Test("EVM7. resend 冷卻中（resendSecondsRemaining = 30）→ useCase 未呼叫")
    func resend_duringCooldown_isIgnored() async {
        // Given
        let (vm, _, fakeResend, _) = makeSUT()
        vm.resendSecondsRemaining = 30

        // When
        await vm.resend()

        // Then
        #expect(fakeResend.callCount == 0)
    }

    @MainActor
    @Test("EVM8. displayName = nil（延後驗證路徑）→ 驗證成功、快取名稱不變")
    func verify_nilDisplayName_skipsCacheUpdate() async {
        // Given
        let (vm, fakeVerify, _, fakeProvider) = makeSUT(displayName: nil)
        vm.code = "123456"

        // When
        await vm.verify()

        // Then
        #expect(vm.error == nil)
        #expect(fakeVerify.lastDisplayName == nil)
        #expect(fakeProvider.currentUser.displayName == "原名")
    }
}

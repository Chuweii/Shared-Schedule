import Testing
import Foundation
@testable import Shared_Schedule

struct LoginViewModelTests {

    @MainActor
    private func makeSUT() -> (
        vm: LoginViewModel,
        fakeSignIn: FakeSignInUseCase,
        fakeSignUp: FakeCompleteSignUpUseCase,
        fakeResend: FakeResendVerificationCodeUseCase
    ) {
        let fakeSignIn = FakeSignInUseCase()
        let fakeSignUp = FakeCompleteSignUpUseCase()
        let fakeResend = FakeResendVerificationCodeUseCase()
        let vm = LoginViewModel(
            signInUseCase: fakeSignIn,
            completeSignUpUseCase: fakeSignUp,
            resendVerificationCodeUseCase: fakeResend
        )
        return (vm, fakeSignIn, fakeSignUp, fakeResend)
    }

    // MARK: - signIn (Slice C)

    @MainActor
    @Test("LVM-C1. signIn 兩欄有效 + fakeSignIn 設成功 → error nil、isLoading 結束為 false、useCase called 1 次")
    func signIn_validInputs_succeedsAndCallsUseCase() async {
        // Given
        let (vm, fakeSignIn, _, _) = makeSUT()
        vm.email = "x@y.com"
        vm.password = "password123"

        // When
        await vm.signIn()

        // Then
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
        #expect(fakeSignIn.callCount == 1)
        #expect(fakeSignIn.lastEmail == "x@y.com")
        #expect(fakeSignIn.lastPassword == "password123")
    }

    @MainActor
    @Test("LVM-C2. signIn fakeSignIn 拋 .emailNotConfirmed → error == .emailNotConfirmed、pendingVerification 仍為 nil")
    func signIn_emailNotConfirmed_setsErrorWithoutNavigating() async {
        // Given
        let (vm, fakeSignIn, _, _) = makeSUT()
        fakeSignIn.errorToThrow = .emailNotConfirmed
        vm.email = "x@y.com"
        vm.password = "password123"

        // When
        await vm.signIn()

        // Then
        #expect(vm.error == .emailNotConfirmed)
        #expect(vm.pendingVerification == nil)
        #expect(vm.didSignIn == false)
    }

    @MainActor
    @Test("LVM-C5. signIn 成功 → didSignIn == true（View 據此顯示歡迎回來卡片）")
    func signIn_success_setsDidSignIn() async {
        // Given
        let (vm, _, _, _) = makeSUT()
        vm.email = "x@y.com"
        vm.password = "password123"

        // When
        await vm.signIn()

        // Then
        #expect(vm.didSignIn == true)
    }

    @MainActor
    @Test("signIn fakeSignIn 拋 .invalidCredentials → error == .invalidCredentials")
    func signIn_invalidCredentials_setsError() async {
        // Given
        let (vm, fakeSignIn, _, _) = makeSUT()
        fakeSignIn.errorToThrow = .invalidCredentials
        vm.email = "x@y.com"
        vm.password = "password123"

        // When
        await vm.signIn()

        // Then
        #expect(vm.error == .invalidCredentials)
    }

    @MainActor
    @Test("signIn email 留空（pre-flight）→ error == .emptyEmail、useCase 未呼叫")
    func signIn_emptyEmail_failsPreflight() async {
        // Given
        let (vm, fakeSignIn, _, _) = makeSUT()
        vm.email = "   "
        vm.password = "password123"

        // When
        await vm.signIn()

        // Then
        #expect(vm.error == .emptyEmail)
        #expect(fakeSignIn.callCount == 0)
    }

    // MARK: - signUp (Slice A, LVM1-LVM3)

    @MainActor
    @Test("LVM1. signUp 三欄全有效 + fakeUseCase 設成功 → error nil、isLoading 結束為 false、useCase called 1 次帶正確 args")
    func signUp_validInputs_succeedsAndCallsUseCase() async {
        // Given
        let (vm, _, fakeSignUp, _) = makeSUT()
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = "小明"

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == nil)
        #expect(vm.isLoading == false)
        #expect(fakeSignUp.callCount == 1)
        #expect(fakeSignUp.lastEmail == "x@y.com")
        #expect(fakeSignUp.lastPassword == "password123")
        #expect(fakeSignUp.lastDisplayName == "小明")
    }

    @MainActor
    @Test("LVM2. signUp displayName 留空 → error == .emptyDisplayName、useCase 未呼叫")
    func signUp_emptyDisplayName_failsPreflight() async {
        // Given
        let (vm, _, fakeSignUp, _) = makeSUT()
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = ""

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == .emptyDisplayName)
        #expect(fakeSignUp.callCount == 0)
    }

    @MainActor
    @Test("LVM3. signUp fakeUseCase 拋 .userAlreadyExists → error == .userExists")
    func signUp_useCaseUserAlreadyExists_setsErrorMessage() async {
        // Given
        let (vm, _, fakeSignUp, _) = makeSUT()
        fakeSignUp.errorToThrow = .userAlreadyExists
        vm.email = "x@y.com"
        vm.password = "password123"
        vm.displayName = "小明"

        // When
        await vm.signUp()

        // Then
        #expect(vm.error == .userExists)
    }

    // MARK: - pendingVerification (Slice C)

    @MainActor
    @Test("LVM-C3. signUp 成功 → pendingVerification == (email, displayName)，不再直接進 app")
    func signUp_success_setsPendingVerification() async {
        // Given
        let (vm, _, _, _) = makeSUT()
        vm.email = "  x@y.com  "
        vm.password = "password123"
        vm.displayName = "  小明  "

        // When
        await vm.signUp()

        // Then
        #expect(vm.pendingVerification == LoginViewModel.PendingVerification(
            email: "x@y.com",
            displayName: "小明"
        ))
    }

    @MainActor
    @Test("LVM-C4. proceedToVerification → resend called 1 次、pendingVerification == (email, nil)、error 清空")
    func proceedToVerification_resendsAndNavigates() async {
        // Given
        let (vm, _, _, fakeResend) = makeSUT()
        vm.email = "x@y.com"
        vm.error = .emailNotConfirmed

        // When
        await vm.proceedToVerification()

        // Then
        #expect(fakeResend.callCount == 1)
        #expect(fakeResend.lastEmail == "x@y.com")
        #expect(vm.pendingVerification == LoginViewModel.PendingVerification(
            email: "x@y.com",
            displayName: nil
        ))
        #expect(vm.error == nil)
    }
}

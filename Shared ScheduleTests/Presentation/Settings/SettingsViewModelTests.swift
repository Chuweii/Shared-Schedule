import Testing
import Foundation
@testable import Shared_Schedule

@MainActor
struct SettingsViewModelTests {

    private static let userID = UserID("a1b2c3d4-e5f6-7890-abcd-ef1234567890")

    private func makeSUT(
        displayName: String = "小明"
    ) -> (
        viewModel: SettingsViewModel,
        updateFake: FakeUpdateDisplayNameUseCase,
        deleteFake: FakeDeleteAccountUseCase
    ) {
        let updateFake = FakeUpdateDisplayNameUseCase()
        let deleteFake = FakeDeleteAccountUseCase()
        let provider = FakeCurrentUserProvider(
            user: User(id: Self.userID, displayName: displayName)
        )
        let viewModel = SettingsViewModel(
            updateDisplayNameUseCase: updateFake,
            deleteAccountUseCase: deleteFake,
            currentUserProvider: provider
        )
        return (viewModel, updateFake, deleteFake)
    }

    @Test("SVM1. 初始化 → displayName == currentUser.displayName")
    func init_seedsDisplayNameFromCurrentUser() {
        // Given / When
        let (viewModel, _, _) = makeSUT(displayName: "小明")

        // Then
        #expect(viewModel.displayName == "小明")
    }

    @Test("SVM2. saveDisplayName，FakeUseCase 成功 → didSaveDisplayName == true、displayNameError == nil、callCount == 1")
    func saveDisplayName_success_setsFlagAndClearsError() async throws {
        // Given
        let (viewModel, updateFake, _) = makeSUT()
        viewModel.displayName = "小華"
        updateFake.resultToReturn = try UserProfile(userID: Self.userID, displayName: "小華")

        // When
        await viewModel.saveDisplayName()

        // Then
        #expect(viewModel.didSaveDisplayName == true)
        #expect(viewModel.displayNameError == nil)
        #expect(updateFake.callCount == 1)
        #expect(updateFake.lastDisplayName == "小華")
    }

    @Test("SVM3. saveDisplayName 空白 → displayNameError 設為 localized；useCase 未呼叫")
    func saveDisplayName_empty_setsErrorAndSkipsUseCase() async {
        // Given
        let (viewModel, updateFake, _) = makeSUT()
        viewModel.displayName = "   "

        // When
        await viewModel.saveDisplayName()

        // Then
        #expect(viewModel.displayNameError == String(localized: "settingsErrorEmptyDisplayName"))
        #expect(updateFake.callCount == 0)
    }

    @Test("SVM4. saveDisplayName，FakeUseCase 拋 .persistenceFailure → displayNameError 設為 localized")
    func saveDisplayName_failure_setsError() async {
        // Given
        let (viewModel, updateFake, _) = makeSUT()
        viewModel.displayName = "小華"
        updateFake.errorToThrow = .persistenceFailure

        // When
        await viewModel.saveDisplayName()

        // Then
        #expect(viewModel.displayNameError == String(localized: "settingsErrorSaveFailed"))
        #expect(viewModel.didSaveDisplayName == false)
    }

    @Test("SVM5. deleteAccount — 成功回 true、deleteError nil；失敗回 false、deleteError 設為 localized")
    func deleteAccount_successAndFailure() async {
        // Given: success
        let (viewModel1, _, _) = makeSUT()

        // When
        let ok = await viewModel1.deleteAccount()

        // Then
        #expect(ok == true)
        #expect(viewModel1.deleteError == nil)

        // Given: failure
        let (viewModel2, _, deleteFake2) = makeSUT()
        deleteFake2.errorToThrow = .persistenceFailure

        // When
        let failed = await viewModel2.deleteAccount()

        // Then
        #expect(failed == false)
        #expect(viewModel2.deleteError == String(localized: "settingsErrorDeleteFailed"))
    }
}

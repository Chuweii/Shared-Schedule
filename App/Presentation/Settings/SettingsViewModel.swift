import Foundation

@Observable
final class SettingsViewModel {
    var displayName: String

    private(set) var isSaving = false
    private(set) var isDeletingAccount = false
    private(set) var displayNameError: String?
    private(set) var deleteError: String?
    private(set) var didSaveDisplayName = false

    private let updateDisplayNameUseCase: any UpdateDisplayNameUseCaseProtocol
    private let deleteAccountUseCase: any DeleteAccountUseCaseProtocol

    init(
        updateDisplayNameUseCase: any UpdateDisplayNameUseCaseProtocol,
        deleteAccountUseCase: any DeleteAccountUseCaseProtocol,
        currentUserProvider: any CurrentUserProviderProtocol
    ) {
        self.updateDisplayNameUseCase = updateDisplayNameUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.displayName = currentUserProvider.currentUser.displayName
    }

    func saveDisplayName() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            displayNameError = String(localized: "settingsErrorEmptyDisplayName")
            return
        }
        isSaving = true
        displayNameError = nil
        didSaveDisplayName = false
        do {
            let profile = try await updateDisplayNameUseCase.updateDisplayName(trimmed)
            displayName = profile.displayName
            didSaveDisplayName = true
        } catch UpdateDisplayNameError.invalidDisplayName {
            displayNameError = String(localized: "settingsErrorDisplayNameTooLong")
        } catch {
            displayNameError = String(localized: "settingsErrorSaveFailed")
        }
        isSaving = false
    }

    /// Returns `true` on success so the View can trigger the
    /// `onAccountDeleted` teardown. On failure sets `deleteError`.
    func deleteAccount() async -> Bool {
        isDeletingAccount = true
        deleteError = nil
        do {
            try await deleteAccountUseCase.deleteAccount()
            isDeletingAccount = false
            return true
        } catch {
            deleteError = String(localized: "settingsErrorDeleteFailed")
            isDeletingAccount = false
            return false
        }
    }
}

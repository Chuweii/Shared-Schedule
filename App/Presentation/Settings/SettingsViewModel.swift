import Foundation

@Observable
final class SettingsViewModel {
    /// Presentation-level error cases. The View maps each case to a
    /// `LocalizedStringKey` so messages follow the in-app language
    /// override (`String(localized:)` resolved here would not).
    enum DisplayNameError: Equatable {
        case empty
        case tooLong
        case saveFailed
    }

    var displayName: String

    private(set) var isSaving = false
    private(set) var isDeletingAccount = false
    private(set) var displayNameError: DisplayNameError?
    private(set) var deleteFailed = false
    private(set) var didSaveDisplayName = false

    private let updateDisplayNameUseCase: any UpdateDisplayNameUseCaseProtocol
    private let deleteAccountUseCase: any DeleteAccountUseCaseProtocol
    private let currentUserProvider: any CurrentUserProviderProtocol

    init(
        updateDisplayNameUseCase: any UpdateDisplayNameUseCaseProtocol,
        deleteAccountUseCase: any DeleteAccountUseCaseProtocol,
        currentUserProvider: any CurrentUserProviderProtocol
    ) {
        self.updateDisplayNameUseCase = updateDisplayNameUseCase
        self.deleteAccountUseCase = deleteAccountUseCase
        self.currentUserProvider = currentUserProvider
        self.displayName = currentUserProvider.currentUser.displayName
    }

    func saveDisplayName() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            displayNameError = .empty
            return
        }
        isSaving = true
        displayNameError = nil
        didSaveDisplayName = false
        do {
            let profile = try await updateDisplayNameUseCase.updateDisplayName(trimmed)
            displayName = profile.displayName
            // Refresh the app-wide cache so reopening settings (which
            // re-seeds from currentUser) shows the new name immediately.
            currentUserProvider.updateCachedDisplayName(profile.displayName)
            didSaveDisplayName = true
        } catch UpdateDisplayNameError.invalidDisplayName {
            displayNameError = .tooLong
        } catch {
            displayNameError = .saveFailed
        }
        isSaving = false
    }

    /// Returns `true` on success so the View can trigger the
    /// `onAccountDeleted` teardown. On failure sets `deleteFailed`.
    func deleteAccount() async -> Bool {
        isDeletingAccount = true
        deleteFailed = false
        do {
            try await deleteAccountUseCase.deleteAccount()
            isDeletingAccount = false
            return true
        } catch {
            deleteFailed = true
            isDeletingAccount = false
            return false
        }
    }
}

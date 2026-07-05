import SwiftUI

/// Account section of `SettingsView`: edit display name, sign out, and
/// delete account. Embedded (no ScrollView / background of its own).
struct AccountSettingsView: View {
    @Environment(\.theme) private var theme
    @State var viewModel: SettingsViewModel
    var onSignOut: (() -> Void)?
    var onAccountDeleted: (() -> Void)?

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("settingsAccountSection")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            displayNameField
            destructiveActions
        }
    }

    // MARK: - Display name

    private var displayNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("settingsDisplayNameLabel")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textSecondary)

            HStack(spacing: 12) {
                TextField("settingsDisplayNameLabel", text: $viewModel.displayName)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(theme.bgSecondary)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(theme.borderPrimary, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    Task { await viewModel.saveDisplayName() }
                } label: {
                    Text("settingsSaveDisplayName")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.buttonTextPrimary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(theme.buttonBgPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isSaving)
            }

            if let error = viewModel.displayNameError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(theme.error)
            } else if viewModel.didSaveDisplayName {
                Text("settingsDisplayNameSaved")
                    .font(.caption)
                    .foregroundStyle(theme.success)
            }
        }
    }

    // MARK: - Destructive actions

    private var destructiveActions: some View {
        VStack(spacing: 12) {
            Divider()

            Button(role: .destructive) {
                onSignOut?()
            } label: {
                Text("登出")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.error)
            .background(theme.error02)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Text("settingsDeleteAccount")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.error)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(theme.error, lineWidth: 1)
            )
            .disabled(viewModel.isDeletingAccount)
            .confirmationDialog(
                Text("settingsDeleteAccountConfirmTitle"),
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    Task {
                        if await viewModel.deleteAccount() {
                            onAccountDeleted?()
                        }
                    }
                } label: {
                    Text("settingsDeleteAccountConfirmButton")
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("settingsDeleteAccountConfirmMessage")
            }

            if let error = viewModel.deleteError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(theme.error)
            }
        }
    }
}

#Preview {
    ScrollView {
        AccountSettingsView(
            viewModel: SettingsViewModel(
                updateDisplayNameUseCase: AppDependencies.live.updateDisplayNameUseCase,
                deleteAccountUseCase: AppDependencies.live.deleteAccountUseCase,
                currentUserProvider: AppDependencies.live.currentUserProvider
            )
        )
        .padding()
    }
    .environment(\.theme, ClassicTheme())
}

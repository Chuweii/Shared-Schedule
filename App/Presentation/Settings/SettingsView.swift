import SwiftUI

/// Settings container shown from the schedule list. Stacks the account
/// section (display-name edit, sign out, delete account) above the
/// appearance section (theme picker + preview).
struct SettingsView: View {
    @Environment(\.theme) private var theme
    @State private var viewModel: SettingsViewModel
    private let onSignOut: (() -> Void)?
    private let onAccountDeleted: (() -> Void)?

    init(
        dependencies: AppDependencies,
        onSignOut: (() -> Void)? = nil,
        onAccountDeleted: (() -> Void)? = nil
    ) {
        self.viewModel = SettingsViewModel(
            updateDisplayNameUseCase: dependencies.updateDisplayNameUseCase,
            deleteAccountUseCase: dependencies.deleteAccountUseCase,
            currentUserProvider: dependencies.currentUserProvider
        )
        self.onSignOut = onSignOut
        self.onAccountDeleted = onAccountDeleted
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                AccountSettingsView(
                    viewModel: viewModel,
                    onSignOut: onSignOut,
                    onAccountDeleted: onAccountDeleted
                )

                Divider()

                VStack(alignment: .leading, spacing: 16) {
                    Text("settingsAppearanceSection")
                        .font(.headline)
                        .foregroundStyle(theme.textPrimary)
                    ThemeSettingsView()
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bgPrimary)
    }
}

#Preview {
    NavigationStack {
        SettingsView(dependencies: .live)
            .navigationTitle("設定")
    }
    .environment(\.theme, ClassicTheme())
    .environment(ThemeManager())
}

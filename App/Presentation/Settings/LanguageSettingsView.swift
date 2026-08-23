import SwiftUI

/// Language picker section. Embedded inside `SettingsView` (which owns
/// the ScrollView + section header), mirroring the theme picker rows.
struct LanguageSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(LanguageManager.self) private var languageManager

    var body: some View {
        VStack(spacing: 8) {
            ForEach(LanguageOption.allCases) { option in
                languageRow(for: option)
            }
        }
    }

    private func languageRow(for option: LanguageOption) -> some View {
        let isSelected = languageManager.current == option
        return Button {
            languageManager.select(option)
        } label: {
            HStack {
                Text(displayName(for: option))
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.system)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? theme.system02 : theme.bgSecondary)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? theme.system : theme.borderPrimary, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func displayName(for option: LanguageOption) -> LocalizedStringKey {
        switch option {
        case .system: "languageOptionSystem"
        case .traditionalChinese: "languageOptionChineseTraditional"
        case .english: "languageOptionEnglish"
        case .japanese: "languageOptionJapanese"
        }
    }
}

#Preview {
    LanguageSettingsView()
        .environment(\.theme, ClassicTheme())
        .environment(LanguageManager())
        .padding()
}

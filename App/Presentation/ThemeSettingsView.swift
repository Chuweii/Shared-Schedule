//
//  ThemeSettingsView.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

/// Pure appearance section. Embedded inside `SettingsView` (which owns
/// the ScrollView + background). Sign-out now lives in the account
/// section of `AccountSettingsView`.
struct ThemeSettingsView: View {
    @Environment(\.theme) private var theme
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 24) {
            themePicker
            previewSection
        }
    }

    // MARK: - Theme Picker

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Theme")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 8) {
                ForEach(ThemeOption.allCases) { option in
                    themeRow(for: option)
                }
            }
        }
    }

    private func themeRow(for option: ThemeOption) -> some View {
        let isSelected = themeManager.current == option
        return Button {
            themeManager.select(option)
        } label: {
            HStack {
                Text(option.displayName)
                    .font(.body)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(theme.system)
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
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            textSample
            buttonSample
            statusSample
        }
    }

    private var textSample: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Primary Text")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.textPrimary)
            Text("Secondary text gives a softer, supporting voice.")
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
            Text("Caption — small footnote style")
                .font(.caption)
                .foregroundStyle(theme.textCaption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(theme.bgSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var buttonSample: some View {
        HStack(spacing: 12) {
            Button {} label: {
                Text("Primary")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.buttonTextPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.buttonBgPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            Button {} label: {
                Text("Secondary")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.buttonTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(theme.buttonBgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    private var statusSample: some View {
        VStack(spacing: 8) {
            statusChip(label: "Success", fg: theme.success, bg: theme.success02)
            statusChip(label: "Warning", fg: theme.warning, bg: theme.warning02)
            statusChip(label: "Error", fg: theme.error, bg: theme.error02)
        }
    }

    private func statusChip(label: String, fg: Color, bg: Color) -> some View {
        HStack {
            Circle()
                .fill(fg)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview("Classic Light") {
    ThemeSettingsView()
        .environment(\.theme, ClassicTheme())
        .environment(ThemeManager())
        .preferredColorScheme(.light)
}

#Preview("Classic Dark") {
    ThemeSettingsView()
        .environment(\.theme, ClassicTheme())
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

#Preview("Midnight Light") {
    ThemeSettingsView()
        .environment(\.theme, MidnightTheme())
        .environment(ThemeManager())
        .preferredColorScheme(.light)
}

#Preview("Midnight Dark") {
    ThemeSettingsView()
        .environment(\.theme, MidnightTheme())
        .environment(ThemeManager())
        .preferredColorScheme(.dark)
}

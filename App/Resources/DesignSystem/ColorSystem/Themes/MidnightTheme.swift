//
//  MidnightTheme.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

struct MidnightTheme: SemanticColorProtocol {

    // MARK: - Text

    var textPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var textSecondary: Color {
        .adaptive(light: .purple300, dark: .purple300)
    }
    var textCaption: Color {
        .adaptive(light: .purple300.opacity(0.75), dark: .purple300.opacity(0.7))
    }
    var textDisable: Color {
        .adaptive(light: .purple300.opacity(0.4), dark: .purple300.opacity(0.35))
    }

    // MARK: - TextField Background

    var textFieldBgPrimary: Color {
        .adaptive(light: .purple800, dark: .purple800)
    }
    var textFieldBgSecondary: Color {
        .adaptive(light: .purple700, dark: .purple900)
    }
    var textFieldBgTertiary: Color {
        .adaptive(light: .purple800, dark: .purple700)
    }

    // MARK: - Icon

    var iconPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var iconSecondary: Color {
        .adaptive(light: .purple300, dark: .purple300)
    }
    var iconTertiary: Color {
        .adaptive(light: .purple300.opacity(0.6), dark: .purple300.opacity(0.55))
    }
    var iconDisable: Color {
        .adaptive(light: .purple300.opacity(0.35), dark: .purple300.opacity(0.3))
    }
    var iconBackground: Color {
        .adaptive(light: .purple800, dark: .purple800)
    }

    // MARK: - Button Background

    var buttonBgPrimary: Color {
        .adaptive(light: .purple500, dark: .purple500)
    }
    var buttonBgSecondary: Color {
        .adaptive(light: .purple800, dark: .purple800)
    }
    var buttonBgDisable: Color {
        .adaptive(light: .purple800.opacity(0.5), dark: .purple800.opacity(0.5))
    }

    // MARK: - Button Text

    var buttonTextPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var buttonTextSecondary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var buttonTextTertiary: Color {
        .adaptive(light: .purple300, dark: .purple300)
    }
    var buttonTextDisable: Color {
        .adaptive(light: .purple300.opacity(0.45), dark: .purple300.opacity(0.4))
    }

    // MARK: - Background

    var bgPrimary: Color {
        .adaptive(light: .purple700, dark: .purple900)
    }
    var bgSecondary: Color {
        .adaptive(light: .purple800, dark: .purple800)
    }
    var bgTertiary: Color {
        .adaptive(light: .purple800, dark: .purple700)
    }

    // MARK: - Border

    var borderPrimary: Color {
        .adaptive(light: .purple500.opacity(0.5), dark: .purple500.opacity(0.4))
    }
    var borderSecondary: Color {
        .adaptive(light: .purple800, dark: .purple700)
    }
    var borderTertiary: Color {
        .adaptive(light: .purple800.opacity(0.5), dark: .purple700.opacity(0.5))
    }

    // MARK: - System

    // Accent/status text brightened for WCAG AA on the dark purple
    // grounds (2026-08 a11y contrast pass).
    var system: Color {
        .adaptive(light: .purple400, dark: .purple400)
    }
    var system02: Color {
        .adaptive(light: .purple400.opacity(0.15), dark: .purple400.opacity(0.25))
    }
    var success: Color {
        .adaptive(light: .green400, dark: .green400)
    }
    var success02: Color {
        .adaptive(light: .green400.opacity(0.15), dark: .green400.opacity(0.2))
    }
    var warning: Color {
        .adaptive(light: .orange500, dark: .orange500)
    }
    var warning02: Color {
        .adaptive(light: .orange500.opacity(0.15), dark: .orange500.opacity(0.2))
    }
    var error: Color {
        .adaptive(light: .red300, dark: .red300)
    }
    var error02: Color {
        .adaptive(light: .red300.opacity(0.15), dark: .red300.opacity(0.2))
    }
}

//
//  ForestTheme.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

struct ForestTheme: SemanticColorProtocol {

    // MARK: - Text

    var textPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var textSecondary: Color {
        .adaptive(light: .green300, dark: .green300)
    }
    var textCaption: Color {
        .adaptive(light: .green300.opacity(0.75), dark: .green300.opacity(0.7))
    }
    var textDisable: Color {
        .adaptive(light: .green300.opacity(0.4), dark: .green300.opacity(0.35))
    }

    // MARK: - TextField Background

    var textFieldBgPrimary: Color {
        .adaptive(light: .green800, dark: .green800)
    }
    var textFieldBgSecondary: Color {
        .adaptive(light: .green700, dark: .green900)
    }
    var textFieldBgTertiary: Color {
        .adaptive(light: .green800, dark: .green700)
    }

    // MARK: - Icon

    var iconPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var iconSecondary: Color {
        .adaptive(light: .green300, dark: .green300)
    }
    var iconTertiary: Color {
        .adaptive(light: .green300.opacity(0.6), dark: .green300.opacity(0.55))
    }
    var iconDisable: Color {
        .adaptive(light: .green300.opacity(0.35), dark: .green300.opacity(0.3))
    }
    var iconBackground: Color {
        .adaptive(light: .green800, dark: .green800)
    }

    // MARK: - Button Background

    var buttonBgPrimary: Color {
        .adaptive(light: .green600, dark: .green600)
    }
    var buttonBgSecondary: Color {
        .adaptive(light: .green800, dark: .green800)
    }
    var buttonBgDisable: Color {
        .adaptive(light: .green800.opacity(0.5), dark: .green800.opacity(0.5))
    }

    // MARK: - Button Text

    var buttonTextPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var buttonTextSecondary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var buttonTextTertiary: Color {
        .adaptive(light: .green300, dark: .green300)
    }
    var buttonTextDisable: Color {
        .adaptive(light: .green300.opacity(0.45), dark: .green300.opacity(0.4))
    }

    // MARK: - Background

    var bgPrimary: Color {
        .adaptive(light: .green700, dark: .green900)
    }
    var bgSecondary: Color {
        .adaptive(light: .green800, dark: .green800)
    }
    var bgTertiary: Color {
        .adaptive(light: .green800, dark: .green700)
    }

    // MARK: - Border

    var borderPrimary: Color {
        .adaptive(light: .green600.opacity(0.5), dark: .green600.opacity(0.4))
    }
    var borderSecondary: Color {
        .adaptive(light: .green800, dark: .green700)
    }
    var borderTertiary: Color {
        .adaptive(light: .green800.opacity(0.5), dark: .green700.opacity(0.5))
    }

    // MARK: - System

    var system: Color {
        .adaptive(light: .green600, dark: .green600)
    }
    var system02: Color {
        .adaptive(light: .green600.opacity(0.15), dark: .green600.opacity(0.25))
    }
    var success: Color {
        .adaptive(light: .green500, dark: .green500)
    }
    var success02: Color {
        .adaptive(light: .green500.opacity(0.15), dark: .green500.opacity(0.2))
    }
    var warning: Color {
        .adaptive(light: .orange500, dark: .orange500)
    }
    var warning02: Color {
        .adaptive(light: .orange500.opacity(0.15), dark: .orange500.opacity(0.2))
    }
    var error: Color {
        .adaptive(light: .red500, dark: .red500)
    }
    var error02: Color {
        .adaptive(light: .red500.opacity(0.15), dark: .red500.opacity(0.2))
    }
}

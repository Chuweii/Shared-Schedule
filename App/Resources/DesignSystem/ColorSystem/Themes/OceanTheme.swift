//
//  OceanTheme.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

struct OceanTheme: SemanticColorProtocol {

    // MARK: - Text

    var textPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var textSecondary: Color {
        .adaptive(light: .blue300, dark: .blue300)
    }
    var textCaption: Color {
        .adaptive(light: .blue300.opacity(0.75), dark: .blue300.opacity(0.7))
    }
    var textDisable: Color {
        .adaptive(light: .blue300.opacity(0.4), dark: .blue300.opacity(0.35))
    }

    // MARK: - TextField Background

    var textFieldBgPrimary: Color {
        .adaptive(light: .blue800, dark: .blue800)
    }
    var textFieldBgSecondary: Color {
        .adaptive(light: .blue700, dark: .blue900)
    }
    var textFieldBgTertiary: Color {
        .adaptive(light: .blue800, dark: .blue700)
    }

    // MARK: - Icon

    var iconPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var iconSecondary: Color {
        .adaptive(light: .blue300, dark: .blue300)
    }
    var iconTertiary: Color {
        .adaptive(light: .blue300.opacity(0.6), dark: .blue300.opacity(0.55))
    }
    var iconDisable: Color {
        .adaptive(light: .blue300.opacity(0.35), dark: .blue300.opacity(0.3))
    }
    var iconBackground: Color {
        .adaptive(light: .blue800, dark: .blue800)
    }

    // MARK: - Button Background

    var buttonBgPrimary: Color {
        .adaptive(light: .blue500, dark: .blue500)
    }
    var buttonBgSecondary: Color {
        .adaptive(light: .blue800, dark: .blue800)
    }
    var buttonBgDisable: Color {
        .adaptive(light: .blue800.opacity(0.5), dark: .blue800.opacity(0.5))
    }

    // MARK: - Button Text

    var buttonTextPrimary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var buttonTextSecondary: Color {
        .adaptive(light: .gray0, dark: .gray0)
    }
    var buttonTextTertiary: Color {
        .adaptive(light: .blue300, dark: .blue300)
    }
    var buttonTextDisable: Color {
        .adaptive(light: .blue300.opacity(0.45), dark: .blue300.opacity(0.4))
    }

    // MARK: - Background

    var bgPrimary: Color {
        .adaptive(light: .blue700, dark: .blue900)
    }
    var bgSecondary: Color {
        .adaptive(light: .blue800, dark: .blue800)
    }
    var bgTertiary: Color {
        .adaptive(light: .blue800, dark: .blue700)
    }

    // MARK: - Border

    var borderPrimary: Color {
        .adaptive(light: .blue500.opacity(0.5), dark: .blue500.opacity(0.4))
    }
    var borderSecondary: Color {
        .adaptive(light: .blue800, dark: .blue700)
    }
    var borderTertiary: Color {
        .adaptive(light: .blue800.opacity(0.5), dark: .blue700.opacity(0.5))
    }

    // MARK: - System

    var system: Color {
        .adaptive(light: .blue500, dark: .blue500)
    }
    var system02: Color {
        .adaptive(light: .blue500.opacity(0.15), dark: .blue500.opacity(0.25))
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

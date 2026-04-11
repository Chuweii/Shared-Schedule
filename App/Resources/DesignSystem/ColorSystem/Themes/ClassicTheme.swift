//
//  ClassicTheme.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

struct ClassicTheme: SemanticColorProtocol {

    // MARK: - Text

    var textPrimary: Color {
        .adaptive(light: .gray1000, dark: .gray0)
    }
    var textSecondary: Color {
        .adaptive(light: .gray600, dark: .gray400)
    }
    var textCaption: Color {
        .adaptive(light: .gray500, dark: .gray500)
    }
    var textDisable: Color {
        .adaptive(light: .gray300, dark: .gray700)
    }

    // MARK: - TextField Background

    var textFieldBgPrimary: Color {
        .adaptive(light: .gray0, dark: .gray800)
    }
    var textFieldBgSecondary: Color {
        .adaptive(light: .gray50, dark: .gray700)
    }
    var textFieldBgTertiary: Color {
        .adaptive(light: .gray100, dark: .gray600)
    }

    // MARK: - Icon

    var iconPrimary: Color {
        .adaptive(light: .gray1000, dark: .gray0)
    }
    var iconSecondary: Color {
        .adaptive(light: .gray600, dark: .gray400)
    }
    var iconTertiary: Color {
        .adaptive(light: .gray400, dark: .gray500)
    }
    var iconDisable: Color {
        .adaptive(light: .gray300, dark: .gray700)
    }
    var iconBackground: Color {
        .adaptive(light: .gray100, dark: .gray700)
    }

    // MARK: - Button Background

    var buttonBgPrimary: Color {
        .adaptive(light: .brandPrimary, dark: .gray0)
    }
    var buttonBgSecondary: Color {
        .adaptive(light: .gray100, dark: .gray700)
    }
    var buttonBgDisable: Color {
        .adaptive(light: .gray100, dark: .gray800)
    }

    // MARK: - Button Text

    var buttonTextPrimary: Color {
        .adaptive(light: .gray0, dark: .gray1000)
    }
    var buttonTextSecondary: Color {
        .adaptive(light: .gray1000, dark: .gray0)
    }
    var buttonTextTertiary: Color {
        .adaptive(light: .gray600, dark: .gray400)
    }
    var buttonTextDisable: Color {
        .adaptive(light: .gray400, dark: .gray600)
    }

    // MARK: - Background

    var bgPrimary: Color {
        .adaptive(light: .gray0, dark: .gray1000)
    }
    var bgSecondary: Color {
        .adaptive(light: .gray50, dark: .gray800)
    }
    var bgTertiary: Color {
        .adaptive(light: .gray100, dark: .gray700)
    }

    // MARK: - Border

    var borderPrimary: Color {
        .adaptive(light: .gray300, dark: .gray700)
    }
    var borderSecondary: Color {
        .adaptive(light: .gray100, dark: .gray800)
    }
    var borderTertiary: Color {
        .adaptive(light: .gray50, dark: .gray800)
    }

    // MARK: - System

    var system: Color {
        .adaptive(light: .blue500, dark: .blue500)
    }
    var system02: Color {
        .adaptive(light: .blue500.opacity(0.1), dark: .blue500.opacity(0.2))
    }
    var success: Color {
        .adaptive(light: .green500, dark: .green500)
    }
    var success02: Color {
        .adaptive(light: .green500.opacity(0.1), dark: .green500.opacity(0.2))
    }
    var warning: Color {
        .adaptive(light: .orange500, dark: .orange500)
    }
    var warning02: Color {
        .adaptive(light: .orange500.opacity(0.1), dark: .orange500.opacity(0.2))
    }
    var error: Color {
        .adaptive(light: .red500, dark: .red500)
    }
    var error02: Color {
        .adaptive(light: .red500.opacity(0.1), dark: .red500.opacity(0.2))
    }
}

//
//  Color+Semantic.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/3/1.
//

import SwiftUI

public protocol SemanticColorProtocol: Sendable {
    // MARK: - Text

    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textCaption: Color { get }
    var textDisable: Color { get }

    // MARK: - TextField Background

    var textFieldBgPrimary: Color { get }
    var textFieldBgSecondary: Color { get }
    var textFieldBgTertiary: Color { get }

    // MARK: - Icon

    var iconPrimary: Color { get }
    var iconSecondary: Color { get }
    var iconTertiary: Color { get }
    var iconDisable: Color { get }
    var iconBackground: Color { get }

    // MARK: - Button Background

    var buttonBgPrimary: Color { get }
    var buttonBgSecondary: Color { get }
    var buttonBgDisable: Color { get }

    // MARK: - Button Text

    var buttonTextPrimary: Color { get }
    var buttonTextSecondary: Color { get }
    var buttonTextTertiary: Color { get }
    var buttonTextDisable: Color { get }

    // MARK: - Background

    var bgPrimary: Color { get }
    var bgSecondary: Color { get }
    var bgTertiary: Color { get }
    
    // MARK: - Border
    
    var borderPrimary: Color { get }
    var borderSecondary: Color { get }
    var borderTertiary: Color { get }
    
    // MARK: - System
    
    var system: Color { get }
    var system02: Color { get }
    var success: Color { get }
    var success02: Color { get }
    var warning: Color { get }
    var warning02: Color { get }
    var error: Color { get }
    var error02: Color { get }
}

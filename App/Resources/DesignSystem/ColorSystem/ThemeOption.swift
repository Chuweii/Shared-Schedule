//
//  ThemeOption.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

enum ThemeOption: String, CaseIterable, Identifiable {
    case classic
    case midnight
    case ocean
    case forest

    var id: String { rawValue }

    /// The colored themes (Forest / Midnight / Ocean) are dark-ground
    /// designs regardless of the device appearance, but system-drawn
    /// chrome (navigation titles, alerts, Form controls) colors itself
    /// from the *device* color scheme — black titles on dark grounds.
    /// Declaring the window dark for these themes makes every system
    /// component resolve correctly; `.adaptive` tokens then use their
    /// dark variants as the canonical look. Classic returns `nil` and
    /// follows the system.
    var preferredColorScheme: ColorScheme? {
        self == .classic ? nil : .dark
    }


    var displayName: String {
        switch self {
        case .classic: "Classic"
        case .midnight: "Midnight"
        case .ocean: "Ocean"
        case .forest: "Forest"
        }
    }

    func makeTheme() -> any SemanticColorProtocol {
        switch self {
        case .classic: ClassicTheme()
        case .midnight: MidnightTheme()
        case .ocean: OceanTheme()
        case .forest: ForestTheme()
        }
    }
}

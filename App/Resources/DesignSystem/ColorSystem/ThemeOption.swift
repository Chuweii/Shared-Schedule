//
//  ThemeOption.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import Foundation

enum ThemeOption: String, CaseIterable, Identifiable {
    case classic
    case midnight
    case ocean
    case forest

    var id: String { rawValue }

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

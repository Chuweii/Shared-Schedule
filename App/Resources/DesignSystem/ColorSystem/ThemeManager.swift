//
//  ThemeManager.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import Foundation

@Observable
final class ThemeManager {
    private static let storageKey = "app.theme.selected"

    private(set) var current: ThemeOption

    var currentTheme: any SemanticColorProtocol {
        current.makeTheme()
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.storageKey) ?? ""
        self.current = ThemeOption(rawValue: raw) ?? .classic
    }

    func select(_ option: ThemeOption) {
        guard option != current else { return }
        current = option
        UserDefaults.standard.set(option.rawValue, forKey: Self.storageKey)
    }
}

//
//  Theme+Environment.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/4/11.
//

import SwiftUI

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: any SemanticColorProtocol = ClassicTheme()
}

extension EnvironmentValues {
    var theme: any SemanticColorProtocol {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

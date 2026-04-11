//
//  Shared_ScheduleApp.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/3/1.
//

import SwiftUI

@main
struct Shared_ScheduleApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.theme, themeManager.currentTheme)
                .environment(themeManager)
        }
    }
}

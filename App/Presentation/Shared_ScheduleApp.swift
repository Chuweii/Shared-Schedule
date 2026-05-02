import SwiftUI

@main
struct Shared_ScheduleApp: App {
    @State private var themeManager = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, themeManager.currentTheme)
                .environment(themeManager)
        }
    }
}

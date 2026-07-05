import SwiftUI

@main
struct Shared_ScheduleApp: App {
    @State private var themeManager = ThemeManager()
    @State private var languageManager = LanguageManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.theme, themeManager.currentTheme)
                .environment(themeManager)
                .environment(languageManager)
                // Follow System pins nothing stale: iOS relaunches the
                // app when the device language changes.
                .environment(\.locale, languageManager.overrideLocale ?? Locale.current)
        }
    }
}

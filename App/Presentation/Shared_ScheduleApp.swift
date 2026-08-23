import SwiftUI

@main
struct Shared_ScheduleApp: App {
    @State private var themeManager = ThemeManager()
    @State private var languageManager = LanguageManager()
    // Registers the MetricKit subscriber at process start; diagnostics
    // for a crash are delivered by the OS on the next launch.
    @State private var crashReporting = CrashReportingBootstrap()

    var body: some Scene {
        WindowGroup {
            RootView(uploadCrashReportsUseCase: crashReporting.uploadUseCase)
                .environment(\.theme, themeManager.currentTheme)
                .environment(themeManager)
                .environment(languageManager)
                // Follow System pins nothing stale: iOS relaunches the
                // app when the device language changes.
                .environment(\.locale, languageManager.overrideLocale ?? Locale.current)
        }
    }
}

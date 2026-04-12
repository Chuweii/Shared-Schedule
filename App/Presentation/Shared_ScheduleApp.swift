import SwiftUI

@main
struct Shared_ScheduleApp: App {
    @State private var themeManager = ThemeManager()
    private let dependencies = AppDependencies.live

    var body: some Scene {
        WindowGroup {
            ContentView(dependencies: dependencies)
                .environment(\.theme, themeManager.currentTheme)
                .environment(themeManager)
        }
    }
}

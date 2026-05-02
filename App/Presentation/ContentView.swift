import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    var onSignOut: (() async -> Void)?

    var body: some View {
        NavigationStack {
            ScheduleListView(dependencies: dependencies, onSignOut: onSignOut)
        }
    }
}

#Preview {
    ContentView(dependencies: .live)
        .environment(\.theme, ClassicTheme())
        .environment(ThemeManager())
}

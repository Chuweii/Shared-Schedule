import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies
    var onSignOut: (() async -> Void)?
    var onAccountDeleted: (() async -> Void)?

    var body: some View {
        NavigationStack {
            ScheduleListView(
                dependencies: dependencies,
                onSignOut: onSignOut,
                onAccountDeleted: onAccountDeleted
            )
        }
    }
}

#Preview {
    ContentView(dependencies: .live)
        .environment(\.theme, ClassicTheme())
        .environment(ThemeManager())
}

import SwiftUI

struct ContentView: View {
    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            ScheduleListView(dependencies: dependencies)
        }
    }
}

#Preview {
    ContentView(dependencies: .live)
        .environment(\.theme, ClassicTheme())
        .environment(ThemeManager())
}

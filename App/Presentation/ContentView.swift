//
//  ContentView.swift
//  Shared Schedule
//
//  Created by Wei Chu  on 2026/3/1.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ThemeSettingsView()
    }
}

#Preview {
    ContentView()
        .environment(\.theme, ClassicTheme())
        .environment(ThemeManager())
}

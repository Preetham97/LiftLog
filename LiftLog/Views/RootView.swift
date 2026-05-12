import SwiftUI
import SwiftData

struct RootView: View {
    @StateObject private var unitPref = UnitPreference()

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "dumbbell.fill") }

            RoutinesView()
                .tabItem { Label("Routines", systemImage: "list.bullet.rectangle") }

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.line.uptrend.xyaxis") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .environmentObject(unitPref)
        .preferredColorScheme(unitPref.theme.colorScheme)
    }
}

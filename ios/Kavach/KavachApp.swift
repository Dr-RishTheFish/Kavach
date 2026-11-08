import SwiftUI

@main
struct KavachApp: App {
    var body: some Scene { WindowGroup { AppRootView() } }
}

struct AppRootView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { HomeView { selection = 1 } }
                .tabItem { Label("Home", systemImage: "house") }.tag(0)
            NavigationStack { AnalyzeView() }
                .tabItem { Label("Analyze", systemImage: "viewfinder") }.tag(1)
            NavigationStack { CircleView() }
                .tabItem { Label("Circle", systemImage: "person.2") }.tag(2)
            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(3)
        }
        .tint(Theme.accent)
    }
}

#Preview { AppRootView() }

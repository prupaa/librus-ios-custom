import SwiftUI

public struct MainTabView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: Int = 0

    public var body: some View {
        TabView(selection: $selectedTab) {
            TimetableView(appState: appState)
                .tabItem {
                    Label("Plan lekcji", systemImage: "calendar")
                }
                .tag(0)

            GradesView(appState: appState)
                .tabItem {
                    Label("Oceny", systemImage: "graduationcap.fill")
                }
                .tag(1)

            AttendanceView(appState: appState)
                .tabItem {
                    Label("Frekwencja", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            MessagesView(appState: appState)
                .tabItem {
                    Label("Wiadomości", systemImage: "envelope.fill")
                }
                .badge(appState.unreadMessagesCount)
                .tag(3)

            SettingsView(appState: appState)
                .tabItem {
                    Label("Ustawienia", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(appState.selectedTheme.color)
    }
}

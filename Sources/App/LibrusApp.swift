import SwiftUI
import UserNotifications

@main
struct LibrusApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Poproś o uprawnienia do powiadomień przy starcie
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(appState: appState)
                .preferredColorScheme(.none) // Dostosowuje się do trybu ciemnego/jasnego iOS
        }
    }
}

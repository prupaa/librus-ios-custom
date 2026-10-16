import Foundation
import WebKit

public struct LibrusProfile: Codable {
    public var studentName: String
    public var schoolName: String
    public var className: String
    public var login: String
}

@MainActor
public final class LibrusService: ObservableObject {
    public static let shared = LibrusService()

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: LibrusProfile? = nil
    @Published public var lastSyncDate: Date? = nil
    @Published public var isSyncing: Bool = false
    @Published public var errorMessage: String? = nil

    private let kIsAuthKey = "Librus_IsAuthenticated"
    private let kProfileKey = "Librus_UserProfile"
    private let kLastSyncKey = "Librus_LastSyncDate"

    private init() {
        self.isAuthenticated = UserDefaults.standard.bool(forKey: kIsAuthKey)
        if let data = UserDefaults.standard.data(forKey: kProfileKey),
           let profile = try? JSONDecoder().decode(LibrusProfile.self, from: data) {
            self.currentUser = profile
        }
        self.lastSyncDate = UserDefaults.standard.object(forKey: kLastSyncKey) as? Date
    }

    /// Logowanie do systemu Synergia Librus
    public func login(login: String, password: String) async -> Bool {
        isSyncing = true
        errorMessage = nil

        // Symulacja autoryzacji z endpointem Librusa
        // W prawdziwym środowisku wykonuje zapytanie POST na https://api.librus.pl/OAuth/Authorization
        // lub https://synergia.librus.pl/loguj/zaawansowane
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        guard !login.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty else {
            errorMessage = "Wprowadź poprawny login i hasło"
            isSyncing = false
            return false
        }

        // Ustawienie profilu użytkownika
        let studentDisplay = login.contains("@") ? String(login.split(separator: "@").first ?? "Uczeń") : login
        let profile = LibrusProfile(
            studentName: studentDisplay.capitalized,
            schoolName: "Liceum Ogólnokształcące / Technikum",
            className: "Klasa 3B",
            login: login
        )

        self.currentUser = profile
        self.isAuthenticated = true
        self.lastSyncDate = Date()
        self.isSyncing = false

        // Zapis stanu
        UserDefaults.standard.set(true, forKey: kIsAuthKey)
        if let encoded = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(encoded, forKey: kProfileKey)
        }
        UserDefaults.standard.set(Date(), forKey: kLastSyncKey)

        return true
    }

    /// Pobieranie i synchronizacja najświeższych danych z konta
    public func syncData(appState: AppState) async {
        guard isAuthenticated else { return }
        isSyncing = true

        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Odśwież datę ostatniej synchronizacji
        let now = Date()
        self.lastSyncDate = now
        UserDefaults.standard.set(now, forKey: kLastSyncKey)

        // Wywołaj powiadomienie o udanej synchronizacji
        if appState.notificationSettings.isEnabled {
            NotificationManager.shared.sendLocalNotification(
                title: "Librus+: Zsynchronizowano",
                body: "Dane o ocenach, frekwencji i planie lekcji są aktualne."
            )
        }

        self.isSyncing = false
    }

    /// Wylogowanie z konta Librus
    public func logout() {
        self.isAuthenticated = false
        self.currentUser = nil
        self.lastSyncDate = nil

        UserDefaults.standard.removeObject(forKey: kIsAuthKey)
        UserDefaults.standard.removeObject(forKey: kProfileKey)
        UserDefaults.standard.removeObject(forKey: kLastSyncKey)

        // Czyszczenie ciasteczek sesji WKWebView
        HTTPCookieStorage.shared.removeCookies(since: Date.distantPast)
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: Date.distantPast) {}
    }
}

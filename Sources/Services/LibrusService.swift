import Foundation
import WebKit

public struct LibrusProfile: Codable {
    public var studentName: String
    public var schoolName: String
    public var className: String
    public var login: String
}

@MainActor
public final class LibrusService: NSObject, ObservableObject, URLSessionTaskDelegate {
    public static let shared = LibrusService()

    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: LibrusProfile? = nil
    @Published public var lastSyncDate: Date? = nil
    @Published public var isSyncing: Bool = false
    @Published public var errorMessage: String? = nil

    private let kIsAuthKey = "Librus_IsAuthenticated"
    private let kProfileKey = "Librus_UserProfile"
    private let kLastSyncKey = "Librus_LastSyncDate"

    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private var session: URLSession!

    private override init() {
        super.init()
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

        self.isAuthenticated = UserDefaults.standard.bool(forKey: kIsAuthKey)
        if let data = UserDefaults.standard.data(forKey: kProfileKey),
           let profile = try? JSONDecoder().decode(LibrusProfile.self, from: data) {
            self.currentUser = profile
        }
        self.lastSyncDate = UserDefaults.standard.object(forKey: kLastSyncKey) as? Date
    }

    // MARK: - URLSessionTaskDelegate (Przechwytywanie przekierowań 302 jak w axios maxRedirects: 0)

    nonisolated public func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        if let url = task.originalRequest?.url?.absoluteString,
           url.contains("loguj") || url.contains("OAuth") || url.contains("Authorization") {
            // Zatrzymujemy automatyczne przekierowanie, aby odczytać nagłówek Location
            completionHandler(nil)
        } else {
            completionHandler(request)
        }
    }

    // MARK: - Autoryzacja Librus (Zgodna z Mati365/librus-api)

    public func login(login: String, password pass: String) async -> Bool {
        isSyncing = true
        errorMessage = nil

        do {
            // Krok 1: GET https://synergia.librus.pl/loguj/portalRodzina
            guard let portalUrl = URL(string: "https://synergia.librus.pl/loguj/portalRodzina") else {
                throw NSError(domain: "Librus", code: -1, userInfo: [NSLocalizedDescriptionKey: "Błędny URL portalu"])
            }
            var req1 = URLRequest(url: portalUrl)
            req1.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req1.setValue("https://portal.librus.pl/", forHTTPHeaderField: "Referer")

            let (r1Data, r1Resp) = try await session.data(for: req1)
            let authRedirectUrl = try getRedirectLocation(from: r1Resp, fallbackBase: portalUrl)

            // Krok 2: GET authorizationUrl
            var req2 = URLRequest(url: authRedirectUrl)
            req2.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req2.setValue(portalUrl.absoluteString, forHTTPHeaderField: "Referer")

            let (_, r2Resp) = try await session.data(for: req2)
            let loginFormUrl = try getRedirectLocation(from: r2Resp, fallbackBase: authRedirectUrl)

            // Krok 3: GET loginFormUrl
            var req3 = URLRequest(url: loginFormUrl)
            req3.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req3.setValue(authRedirectUrl.absoluteString, forHTTPHeaderField: "Referer")
            _ = try await session.data(for: req3)

            // Krok 4: POST credentials z nagłówkiem x-baner
            var req4 = URLRequest(url: loginFormUrl)
            req4.httpMethod = "POST"
            req4.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            req4.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            req4.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
            req4.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
            req4.setValue(makeBannerHeader(), forHTTPHeaderField: "x-baner")
            req4.setValue(loginFormUrl.absoluteString, forHTTPHeaderField: "Referer")
            req4.setValue("https://api.librus.pl", forHTTPHeaderField: "Origin")

            let postParams = "action=login&login=\(urlEncode(login))&pass=\(urlEncode(pass))"
            req4.httpBody = postParams.data(using: .utf8)

            let (loginData, loginResp) = try await session.data(for: req4)

            // Sprawdzamy odpowiedź JSON lub Location
            var continuationUrl: URL? = nil
            if let httpResp = loginResp as? HTTPURLResponse, let loc = httpResp.value(forHTTPHeaderField: "Location"), let u = URL(string: loc, relativeTo: loginFormUrl) {
                continuationUrl = u.absoluteURL
            } else if let json = try? JSONSerialization.jsonObject(with: loginData) as? [String: Any] {
                if let status = json["status"] as? String, status == "ok", let goTo = json["goTo"] as? String {
                    continuationUrl = URL(string: goTo, relativeTo: loginFormUrl)?.absoluteURL
                } else if let msg = json["message"] as? String {
                    throw NSError(domain: "Librus", code: 401, userInfo: [NSLocalizedDescriptionKey: msg])
                }
            }

            guard let finalContinuation = continuationUrl else {
                throw NSError(domain: "Librus", code: 401, userInfo: [NSLocalizedDescriptionKey: "Nieprawidłowy login lub hasło do Librusa."])
            }

            // Krok 5: Podążanie za łańcuchem autoryzacji (OAuth chain) do synergia.librus.pl
            try await followOAuthChain(startUrl: finalContinuation)

            // Krok 6: Pobieranie profilu ucznia
            let profile = await fetchStudentProfile(defaultLogin: login)

            self.currentUser = profile
            self.isAuthenticated = true
            self.lastSyncDate = Date()
            self.isSyncing = false

            UserDefaults.standard.set(true, forKey: kIsAuthKey)
            if let encoded = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(encoded, forKey: kProfileKey)
            }
            UserDefaults.standard.set(Date(), forKey: kLastSyncKey)

            return true
        } catch {
            self.errorMessage = error.localizedDescription
            self.isSyncing = false
            return false
        }
    }

    // MARK: - Synchronizacja Danych z Librusem

    public func syncData(appState: AppState) async {
        guard isAuthenticated else { return }
        isSyncing = true

        do {
            // 1. Pobierz Oceny
            if let gradesHtml = try? await fetchHTML(from: "https://synergia.librus.pl/przegladaj_oceny/uczen") {
                let parsedGrades = LibrusHTMLParser.shared.parseGrades(html: gradesHtml)
                if !parsedGrades.isEmpty {
                    applyParsedGrades(parsedGrades, to: appState)
                }
            }

            // 2. Pobierz Plan Lekcji
            if let timetableHtml = try? await fetchHTML(from: "https://synergia.librus.pl/przegladaj_plan_lekcji") {
                let parsedLessons = LibrusHTMLParser.shared.parseTimetable(html: timetableHtml)
                if !parsedLessons.isEmpty {
                    applyParsedLessons(parsedLessons, to: appState)
                }
            }

            // 3. Pobierz Wiadomości
            if let msgHtml = try? await fetchHTML(from: "https://synergia.librus.pl/wiadomosci") {
                let parsedMessages = LibrusHTMLParser.shared.parseMessages(html: msgHtml)
                if !parsedMessages.isEmpty {
                    applyParsedMessages(parsedMessages, to: appState)
                }
            }

            let now = Date()
            self.lastSyncDate = now
            UserDefaults.standard.set(now, forKey: kLastSyncKey)

            if appState.notificationSettings.isEnabled {
                NotificationManager.shared.sendLocalNotification(
                    title: "Librus+: Zsynchronizowano",
                    body: "Pobrano aktualne oceny, plan lekcji i wiadomości z Synergii."
                )
            }
        }

        self.isSyncing = false
    }

    public func logout() {
        self.isAuthenticated = false
        self.currentUser = nil
        self.lastSyncDate = nil

        UserDefaults.standard.removeObject(forKey: kIsAuthKey)
        UserDefaults.standard.removeObject(forKey: kProfileKey)
        UserDefaults.standard.removeObject(forKey: kLastSyncKey)

        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }

    // MARK: - Pomocnicze Mechanizmy API Mati365

    /// Generowanie nagłówka x-baner z przesunięciem o 20 znaków Unicode
    private func makeBannerHeader() -> String {
        let shift: (String) -> String = { text in
            let scalars = text.unicodeScalars.compactMap { scalar -> Character? in
                guard let newScalar = UnicodeScalar(scalar.value + 20) else { return nil }
                return Character(newScalar)
            }
            return String(scalars)
        }
        let timestamp = Int(Date().timeIntervalSince1970)
        let random = Int.random(in: 100000...999999)
        return "\(shift(String(random))):\(shift(String(timestamp)))"
    }

    private func getRedirectLocation(from response: URLResponse, fallbackBase: URL) throws -> URL {
        if let http = response as? HTTPURLResponse, let loc = http.value(forHTTPHeaderField: "Location"), let url = URL(string: loc, relativeTo: fallbackBase) {
            return url.absoluteURL
        }
        throw NSError(domain: "Librus", code: -1, userInfo: [NSLocalizedDescriptionKey: "Brak przekierowania autoryzacji Librusa."])
    }

    private func followOAuthChain(startUrl: URL) async throws {
        var currentUrl = startUrl
        for _ in 0..<10 {
            var req = URLRequest(url: currentUrl)
            req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            let (_, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse, let loc = http.value(forHTTPHeaderField: "Location"), let next = URL(string: loc, relativeTo: currentUrl) {
                currentUrl = next.absoluteURL
            } else {
                return // Dotarliśmy do końcowej strony sesji
            }
        }
    }

    private func fetchHTML(from urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { return "" }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.setValue("https://synergia.librus.pl/uczen_index", forHTTPHeaderField: "Referer")
        let (data, _) = try await session.data(for: req)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func fetchStudentProfile(defaultLogin: String) async -> LibrusProfile {
        if let html = try? await fetchHTML(from: "https://synergia.librus.pl/informacja"),
           let info = LibrusHTMLParser.shared.parseStudentInfo(html: html) {
            return LibrusProfile(
                studentName: info.name,
                schoolName: info.school,
                className: info.className,
                login: defaultLogin
            )
        }
        return LibrusProfile(
            studentName: defaultLogin.capitalized,
            schoolName: "Szkoła",
            className: "Klasa",
            login: defaultLogin
        )
    }

    private func urlEncode(_ str: String) -> String {
        str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? str
    }

    // MARK: - Aplikowanie Danych do AppState

    private func applyParsedGrades(_ items: [ParsedGradeItem], to appState: AppState) {
        // Mapowanie przedmiotów
        var subjectMap: [String: String] = [:] // Name -> ID
        for s in appState.subjects { subjectMap[s.name] = s.id }

        for item in items {
            if subjectMap[item.subjectName] == nil {
                let newSubj = Subject(name: item.subjectName, teacher: "Nauczyciel", defaultRoom: "")
                appState.subjects.append(newSubj)
                subjectMap[item.subjectName] = newSubj.id
            }
        }

        // Mapowanie ocen
        var newGrades: [Grade] = []
        for item in items {
            guard let sId = subjectMap[item.subjectName] else { continue }
            newGrades.append(Grade(
                subjectId: sId,
                value: item.value,
                displayValue: item.displayValue,
                weight: item.weight,
                category: item.category,
                date: item.date,
                comment: item.comment
            ))
        }

        if !newGrades.isEmpty {
            appState.grades = newGrades
            appState.saveData()
        }
    }

    private func applyParsedLessons(_ items: [ParsedLessonItem], to appState: AppState) {
        var subjectMap: [String: String] = [:]
        for s in appState.subjects { subjectMap[s.name] = s.id }

        var newLessons: [Lesson] = []
        for item in items {
            let sId = subjectMap[item.subjectName] ?? {
                let ns = Subject(name: item.subjectName, teacher: item.teacher, defaultRoom: item.room)
                appState.subjects.append(ns)
                subjectMap[item.subjectName] = ns.id
                return ns.id
            }()

            newLessons.append(Lesson(
                subjectId: sId,
                dayOfWeek: item.dayOfWeek,
                lessonIndex: item.lessonIndex,
                startTime: item.startTime,
                endTime: item.endTime,
                room: item.room,
                teacher: item.teacher,
                breakAfterMinutes: item.breakMinutes
            ))
        }

        if !newLessons.isEmpty {
            appState.lessons = newLessons
            appState.saveData()
        }
    }

    private func applyParsedMessages(_ items: [ParsedMessageItem], to appState: AppState) {
        var newMsgs: [SchoolMessage] = []
        for item in items {
            newMsgs.append(SchoolMessage(
                sender: item.sender,
                recipient: "Uczeń (Ty)",
                subject: item.subject,
                body: item.body,
                date: item.date,
                isRead: item.isRead,
                isSentByUser: false
            ))
        }

        if !newMsgs.isEmpty {
            appState.messages = newMsgs
            appState.saveData()
        }
    }
}

import Foundation
import SwiftUI
import Combine

@MainActor
public final class AppState: ObservableObject {
    // MARK: - Published Properties
    @Published public var subjects: [Subject] = []
    @Published public var grades: [Grade] = []
    @Published public var lessons: [Lesson] = []
    @Published public var events: [ScheduleEvent] = []
    @Published public var attendanceRecords: [AttendanceRecord] = []
    @Published public var monthlyAttendance: [MonthlyAttendance] = []
    @Published public var messages: [SchoolMessage] = []

    // Ustawienia & Customizacja
    @Published public var notificationSettings: NotificationSettings = NotificationSettings()
    @Published public var selectedTheme: AppThemeColor = .blue
    @Published public var backgroundImageData: Data? = nil
    @Published public var backgroundDimOpacity: Double = 0.35
    @Published public var backgroundBlurRadius: Double = 3.0

    // Klucze UserDefaults do trwałego zapisu
    private let kSubjectsKey = "LibrusPlus_Subjects"
    private let kGradesKey = "LibrusPlus_Grades"
    private let kLessonsKey = "LibrusPlus_Lessons"
    private let kEventsKey = "LibrusPlus_Events"
    private let kAttendanceKey = "LibrusPlus_Attendance"
    private let kMonthlyAttendanceKey = "LibrusPlus_MonthlyAttendance"
    private let kMessagesKey = "LibrusPlus_Messages"
    private let kNotificationsKey = "LibrusPlus_NotificationSettings"
    private let kThemeKey = "LibrusPlus_SelectedTheme"
    private let kBgDataKey = "LibrusPlus_BackgroundData"
    private let kBgDimKey = "LibrusPlus_BackgroundDim"
    private let kBgBlurKey = "LibrusPlus_BackgroundBlur"

    public init() {
        loadData()
    }

    // MARK: - Filtrowane i Wyliczane Właściwości

    /// Przedmioty widoczne (bez ukrytych np. Religia, jeśli użytkownik ją wyłączył)
    public var visibleSubjects: [Subject] {
        subjects.filter { !$0.isHidden }
    }

    /// Średnia ważona dla pojedynczego przedmiotu
    public func average(for subjectId: String) -> Double? {
        let subjectGrades = grades.filter { $0.subjectId == subjectId }
        guard !subjectGrades.isEmpty else { return nil }

        let totalWeight = subjectGrades.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return nil }

        let weightedSum = subjectGrades.reduce(0.0) { $0 + ($1.value * Double($1.weight)) }
        return weightedSum / Double(totalWeight)
    }

    /// Średnia ogólna z wszystkich WIDOCZNYCH przedmiotów
    public var overallGPA: Double {
        let activeSubjects = visibleSubjects
        var totalSum = 0.0
        var count = 0

        for s in activeSubjects {
            if let avg = average(for: s.id) {
                totalSum += avg
                count += 1
            }
        }
        guard count > 0 else { return 0.0 }
        return totalSum / Double(count)
    }

    /// Frekwencja ogólna w procentach (tylko widoczne przedmioty)
    public var overallAttendancePercentage: Double {
        let visibleIds = Set(visibleSubjects.map { $0.id })
        let records = attendanceRecords.filter { visibleIds.contains($0.subjectId) }
        guard !records.isEmpty else { return 100.0 }

        let positiveCount = records.filter { $0.status.isPositive }.count
        return (Double(positiveCount) / Double(records.count)) * 100.0
    }

    /// Frekwencja dla danego przedmiotu
    public func attendancePercentage(for subjectId: String) -> Double {
        let records = attendanceRecords.filter { $0.subjectId == subjectId }
        guard !records.isEmpty else { return 100.0 }
        let positive = records.filter { $0.status.isPositive }.count
        return (Double(positive) / Double(records.count)) * 100.0
    }

    /// Statystyki frekwencji
    public var attendanceStats: (lates: Int, latesExcused: Int, absences: Int, absencesExcused: Int, releases: Int) {
        let visibleIds = Set(visibleSubjects.map { $0.id })
        let records = attendanceRecords.filter { visibleIds.contains($0.subjectId) }

        var lates = 0
        var latesExcused = 0
        var absences = 0
        var absencesExcused = 0
        var releases = 0

        for r in records {
            switch r.status {
            case .late: lates += 1
            case .lateExcused: latesExcused += 1
            case .absent: absences += 1
            case .absentExcused: absencesExcused += 1
            case .released: releases += 1
            case .present: break
            }
        }
        return (lates, latesExcused, absences, absencesExcused, releases)
    }

    /// Pobierz nazwę przedmiotu po ID
    public func subjectName(for id: String) -> String {
        subjects.first(where: { $0.id == id })?.name ?? "Przedmiot"
    }

    /// Liczba nieprzeczytanych wiadomości
    public var unreadMessagesCount: Int {
        messages.filter { !$0.isRead && !$0.isSentByUser }.count
    }

    // MARK: - Akcje Użytkownika

    /// Ukrywanie / pokazywanie przedmiotu (np. Religia)
    public func toggleSubjectHidden(id: String) {
        if let idx = subjects.firstIndex(where: { $0.id == id }) {
            subjects[idx].isHidden.toggle()
            saveData()
        }
    }

    /// Dodawanie własnego wydarzenia (sprawdzian, kartkówka) do planu
    public func addScheduleEvent(subjectId: String, dayOfWeek: Int, lessonIndex: Int, title: String, type: EventType, date: Date, note: String = "") {
        let newEvent = ScheduleEvent(
            subjectId: subjectId,
            dayOfWeek: dayOfWeek,
            lessonIndex: lessonIndex,
            title: title,
            type: type,
            date: date,
            note: note
        )
        events.append(newEvent)
        saveData()

        if notificationSettings.isEnabled && notificationSettings.notifyExams {
            let sName = subjectName(for: subjectId)
            NotificationManager.shared.scheduleExamReminder(title: "\(type.rawValue): \(title)", subjectName: sName, date: date)
        }
    }

    public func removeScheduleEvent(id: String) {
        events.removeAll { $0.id == id }
        saveData()
    }

    /// Dodanie nowej oceny (np. symulacja z serwera lub ręczne dodanie)
    public func addGrade(subjectId: String, value: Double, displayValue: String, weight: Int, category: String, comment: String = "") {
        let grade = Grade(subjectId: subjectId, value: value, displayValue: displayValue, weight: weight, category: category, date: Date(), comment: comment)
        grades.insert(grade, at: 0)
        saveData()

        if notificationSettings.isEnabled && notificationSettings.notifyGrades {
            let sName = subjectName(for: subjectId)
            NotificationManager.shared.sendLocalNotification(
                title: "Nowa ocena: \(displayValue) (\(sName))",
                body: "\(category), waga \(weight) - \(comment.isEmpty ? "Brak komentarza" : comment)"
            )
        }
    }

    /// Wysłanie nowej wiadomości
    public func sendMessage(recipient: String, subject: String, body: String) {
        let msg = SchoolMessage(
            sender: "Uczeń (Ty)",
            recipient: recipient,
            subject: subject,
            body: body,
            date: Date(),
            isRead: true,
            isSentByUser: true
        )
        messages.insert(msg, at: 0)
        saveData()
    }

    /// Oznaczenie wiadomości jako przeczytana
    public func markMessageAsRead(id: String) {
        if let idx = messages.firstIndex(where: { $0.id == id }) {
            messages[idx].isRead = true
            saveData()
        }
    }

    /// Symulacja przyjścia wiadomości
    public func simulateIncomingMessage() {
        let randomSenders = ["mgr Anna Nowak", "dr Piotr Wiśniewski", "Sekretariat Szkoły", "Wychowawca klasy"]
        let randomSubjects = ["Konsultacje przed sprawdzianem", "Zebranie z rodzicami", "Materiały do powtórki", "Informacja o wycieczce"]
        let sender = randomSenders.randomElement() ?? "Nauczyciel"
        let subj = randomSubjects.randomElement() ?? "Wiadomość szkolna"

        let msg = SchoolMessage(
            sender: sender,
            recipient: "Uczeń (Ty)",
            subject: subj,
            body: "Dzień dobry,\n\nPrzypominam o terminowym przygotowaniu materiałów oraz sprawdzeniu zadań w podręczniku.\n\nPozdrawiam,\n\(sender)",
            date: Date(),
            isRead: false,
            isSentByUser: false
        )
        messages.insert(msg, at: 0)
        saveData()

        if notificationSettings.isEnabled && notificationSettings.notifyMessages {
            NotificationManager.shared.sendLocalNotification(
                title: "Nowa wiadomość: \(sender)",
                body: subj
            )
        }
    }

    /// Zmiana tła
    public func setBackgroundImage(data: Data?) {
        self.backgroundImageData = data
        saveData()
    }

    // MARK: - Trwały Zapis i Odczyt (Persistence)

    public func saveData() {
        if let encoded = try? JSONEncoder().encode(subjects) { UserDefaults.standard.set(encoded, forKey: kSubjectsKey) }
        if let encoded = try? JSONEncoder().encode(grades) { UserDefaults.standard.set(encoded, forKey: kGradesKey) }
        if let encoded = try? JSONEncoder().encode(lessons) { UserDefaults.standard.set(encoded, forKey: kLessonsKey) }
        if let encoded = try? JSONEncoder().encode(events) { UserDefaults.standard.set(encoded, forKey: kEventsKey) }
        if let encoded = try? JSONEncoder().encode(attendanceRecords) { UserDefaults.standard.set(encoded, forKey: kAttendanceKey) }
        if let encoded = try? JSONEncoder().encode(monthlyAttendance) { UserDefaults.standard.set(encoded, forKey: kMonthlyAttendanceKey) }
        if let encoded = try? JSONEncoder().encode(messages) { UserDefaults.standard.set(encoded, forKey: kMessagesKey) }
        if let encoded = try? JSONEncoder().encode(notificationSettings) { UserDefaults.standard.set(encoded, forKey: kNotificationsKey) }

        UserDefaults.standard.set(selectedTheme.rawValue, forKey: kThemeKey)
        UserDefaults.standard.set(backgroundImageData, forKey: kBgDataKey)
        UserDefaults.standard.set(backgroundDimOpacity, forKey: kBgDimKey)
        UserDefaults.standard.set(backgroundBlurRadius, forKey: kBgBlurKey)
    }

    private func loadData() {
        if let data = UserDefaults.standard.data(forKey: kSubjectsKey),
           let decoded = try? JSONDecoder().decode([Subject].self, from: data) {
            self.subjects = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kGradesKey),
           let decoded = try? JSONDecoder().decode([Grade].self, from: data) {
            self.grades = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kLessonsKey),
           let decoded = try? JSONDecoder().decode([Lesson].self, from: data) {
            self.lessons = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kEventsKey),
           let decoded = try? JSONDecoder().decode([ScheduleEvent].self, from: data) {
            self.events = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kAttendanceKey),
           let decoded = try? JSONDecoder().decode([AttendanceRecord].self, from: data) {
            self.attendanceRecords = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kMonthlyAttendanceKey),
           let decoded = try? JSONDecoder().decode([MonthlyAttendance].self, from: data) {
            self.monthlyAttendance = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kMessagesKey),
           let decoded = try? JSONDecoder().decode([SchoolMessage].self, from: data) {
            self.messages = decoded
        }
        if let data = UserDefaults.standard.data(forKey: kNotificationsKey),
           let decoded = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
            self.notificationSettings = decoded
        }
        if let themeStr = UserDefaults.standard.string(forKey: kThemeKey),
           let theme = AppThemeColor(rawValue: themeStr) {
            self.selectedTheme = theme
        }

        self.backgroundImageData = UserDefaults.standard.data(forKey: kBgDataKey)
        if UserDefaults.standard.object(forKey: kBgDimKey) != nil {
            self.backgroundDimOpacity = UserDefaults.standard.double(forKey: kBgDimKey)
        }
        if UserDefaults.standard.object(forKey: kBgBlurKey) != nil {
            self.backgroundBlurRadius = UserDefaults.standard.double(forKey: kBgBlurKey)
        }

        // Jeśli baza jest pusta, zainicjuj bogate dane początkowe
        if subjects.isEmpty {
            seedSampleData()
        }
    }

    // MARK: - Dane Początkowe (Seed Data)
    private func seedSampleData() {
        let polski = Subject(id: "s_pol", name: "Język polski", teacher: "mgr Anna Nowak", defaultRoom: "102", icon: "book.closed.fill")
        let matma = Subject(id: "s_mat", name: "Matematyka", teacher: "dr Jan Kowalski", defaultRoom: "204", icon: "function")
        let ang = Subject(id: "s_ang", name: "Język angielski", teacher: "mgr Sarah Brown", defaultRoom: "115", icon: "globe.europe.africa.fill")
        let his = Subject(id: "s_his", name: "Historia", teacher: "mgr Piotr Wiśniewski", defaultRoom: "301", icon: "clock.arrow.circlepath")
        let bio = Subject(id: "s_bio", name: "Biologia", teacher: "dr Ewa Zielińska", defaultRoom: "208", icon: "leaf.fill")
        let fiz = Subject(id: "s_fiz", name: "Fizyka", teacher: "mgr Tomasz Wójcik", defaultRoom: "210", icon: "atom")
        let inf = Subject(id: "s_inf", name: "Informatyka", teacher: "inż. Marek Lewandowski", defaultRoom: "Lab 3", icon: "desktopcomputer")
        let wf = Subject(id: "s_wf", name: "Wychowanie fizyczne", teacher: "mgr Robert Lewandowski", defaultRoom: "Hala sportowa", icon: "figure.run")
        let rel = Subject(id: "s_rel", name: "Religia", teacher: "ks. Mariusz Dąbrowski", defaultRoom: "105", icon: "cross.fill", isHidden: false)

        self.subjects = [polski, matma, ang, his, bio, fiz, inf, wf, rel]

        // Oceny
        self.grades = [
            Grade(subjectId: "s_mat", value: 5.0, displayValue: "5", weight: 3, category: "Sprawdzian", comment: "Funkcja liniowa i kwadratowa"),
            Grade(subjectId: "s_mat", value: 4.5, displayValue: "4+", weight: 2, category: "Kartkówka", comment: "Wzory skróconego mnożenia"),
            Grade(subjectId: "s_mat", value: 6.0, displayValue: "6", weight: 1, category: "Aktywność", comment: "Zadanie dodatkowe przy tablicy"),

            Grade(subjectId: "s_pol", value: 4.0, displayValue: "4", weight: 3, category: "Wypracowanie", comment: "Motyw zbrodni i kary w literaturze"),
            Grade(subjectId: "s_pol", value: 5.0, displayValue: "5", weight: 2, category: "Odpowiedź ustna", comment: "Epoka Romantyzmu"),

            Grade(subjectId: "s_ang", value: 5.0, displayValue: "5", weight: 3, category: "Sprawdzian", comment: "Conditional clauses & vocabulary"),
            Grade(subjectId: "s_ang", value: 5.5, displayValue: "5+", weight: 1, category: "Projekt", comment: "Prezentacja multimedialna"),

            Grade(subjectId: "s_bio", value: 3.5, displayValue: "3+", weight: 3, category: "Sprawdzian", comment: "Układ krążenia człowieka"),
            Grade(subjectId: "s_bio", value: 4.0, displayValue: "4", weight: 1, category: "Kartkówka", comment: "Budowa serca"),

            Grade(subjectId: "s_fiz", value: 4.0, displayValue: "4", weight: 3, category: "Sprawdzian", comment: "Zasady dynamiki Newtona"),

            Grade(subjectId: "s_inf", value: 6.0, displayValue: "6", weight: 3, category: "Projekt", comment: "Aplikacja mobilna w SwiftUI"),

            Grade(subjectId: "s_his", value: 4.0, displayValue: "4", weight: 2, category: "Kartkówka", comment: "Konstytucja 3 Maja"),

            Grade(subjectId: "s_wf", value: 5.0, displayValue: "5", weight: 1, category: "Aktywność", comment: "Bieg na 1000m"),

            Grade(subjectId: "s_rel", value: 5.0, displayValue: "5", weight: 1, category: "Zadanie domowe", comment: "Przypowieści biblijne")
        ]

        // Plan lekcji (Poniedziałek - Piątek)
        // breakAfterMinutes: 10, 15 (duża przerwa), 10, 5 itp.
        self.lessons = [
            // Poniedziałek
            Lesson(subjectId: "s_pol", dayOfWeek: 1, lessonIndex: 1, startTime: "08:00", endTime: "08:45", room: "102", teacher: "mgr Anna Nowak", breakAfterMinutes: 10),
            Lesson(subjectId: "s_mat", dayOfWeek: 1, lessonIndex: 2, startTime: "08:55", endTime: "09:40", room: "204", teacher: "dr Jan Kowalski", breakAfterMinutes: 10),
            Lesson(subjectId: "s_ang", dayOfWeek: 1, lessonIndex: 3, startTime: "09:50", endTime: "10:35", room: "115", teacher: "mgr Sarah Brown", breakAfterMinutes: 15),
            Lesson(subjectId: "s_fiz", dayOfWeek: 1, lessonIndex: 4, startTime: "10:50", endTime: "11:35", room: "210", teacher: "mgr Tomasz Wójcik", breakAfterMinutes: 20), // Długa przerwa obiadowa
            Lesson(subjectId: "s_bio", dayOfWeek: 1, lessonIndex: 5, startTime: "11:55", endTime: "12:40", room: "208", teacher: "dr Ewa Zielińska", breakAfterMinutes: 10),
            Lesson(subjectId: "s_wf",  dayOfWeek: 1, lessonIndex: 6, startTime: "12:50", endTime: "13:35", room: "Hala", teacher: "mgr Robert Lewandowski", breakAfterMinutes: 5),

            // Wtorek
            Lesson(subjectId: "s_mat", dayOfWeek: 2, lessonIndex: 1, startTime: "08:00", endTime: "08:45", room: "204", teacher: "dr Jan Kowalski", breakAfterMinutes: 10),
            Lesson(subjectId: "s_pol", dayOfWeek: 2, lessonIndex: 2, startTime: "08:55", endTime: "09:40", room: "102", teacher: "mgr Anna Nowak", breakAfterMinutes: 10),
            Lesson(subjectId: "s_inf", dayOfWeek: 2, lessonIndex: 3, startTime: "09:50", endTime: "10:35", room: "Lab 3", teacher: "inż. Marek Lewandowski", breakAfterMinutes: 15),
            Lesson(subjectId: "s_inf", dayOfWeek: 2, lessonIndex: 4, startTime: "10:50", endTime: "11:35", room: "Lab 3", teacher: "inż. Marek Lewandowski", breakAfterMinutes: 20),
            Lesson(subjectId: "s_his", dayOfWeek: 2, lessonIndex: 5, startTime: "11:55", endTime: "12:40", room: "301", teacher: "mgr Piotr Wiśniewski", breakAfterMinutes: 10),
            Lesson(subjectId: "s_rel", dayOfWeek: 2, lessonIndex: 6, startTime: "12:50", endTime: "13:35", room: "105", teacher: "ks. Mariusz Dąbrowski", breakAfterMinutes: 5),

            // Środa
            Lesson(subjectId: "s_ang", dayOfWeek: 3, lessonIndex: 1, startTime: "08:00", endTime: "08:45", room: "115", teacher: "mgr Sarah Brown", breakAfterMinutes: 10),
            Lesson(subjectId: "s_mat", dayOfWeek: 3, lessonIndex: 2, startTime: "08:55", endTime: "09:40", room: "204", teacher: "dr Jan Kowalski", breakAfterMinutes: 10),
            Lesson(subjectId: "s_bio", dayOfWeek: 3, lessonIndex: 3, startTime: "09:50", endTime: "10:35", room: "208", teacher: "dr Ewa Zielińska", breakAfterMinutes: 15),
            Lesson(subjectId: "s_pol", dayOfWeek: 3, lessonIndex: 4, startTime: "10:50", endTime: "11:35", room: "102", teacher: "mgr Anna Nowak", breakAfterMinutes: 20),
            Lesson(subjectId: "s_wf",  dayOfWeek: 3, lessonIndex: 5, startTime: "11:55", endTime: "12:40", room: "Hala", teacher: "mgr Robert Lewandowski", breakAfterMinutes: 10),

            // Czwartek
            Lesson(subjectId: "s_fiz", dayOfWeek: 4, lessonIndex: 1, startTime: "08:00", endTime: "08:45", room: "210", teacher: "mgr Tomasz Wójcik", breakAfterMinutes: 10),
            Lesson(subjectId: "s_ang", dayOfWeek: 4, lessonIndex: 2, startTime: "08:55", endTime: "09:40", room: "115", teacher: "mgr Sarah Brown", breakAfterMinutes: 10),
            Lesson(subjectId: "s_his", dayOfWeek: 4, lessonIndex: 3, startTime: "09:50", endTime: "10:35", room: "301", teacher: "mgr Piotr Wiśniewski", breakAfterMinutes: 15),
            Lesson(subjectId: "s_mat", dayOfWeek: 4, lessonIndex: 4, startTime: "10:50", endTime: "11:35", room: "204", teacher: "dr Jan Kowalski", breakAfterMinutes: 20),
            Lesson(subjectId: "s_rel", dayOfWeek: 4, lessonIndex: 5, startTime: "11:55", endTime: "12:40", room: "105", teacher: "ks. Mariusz Dąbrowski", breakAfterMinutes: 10),

            // Piątek
            Lesson(subjectId: "s_pol", dayOfWeek: 5, lessonIndex: 1, startTime: "08:00", endTime: "08:45", room: "102", teacher: "mgr Anna Nowak", breakAfterMinutes: 10),
            Lesson(subjectId: "s_mat", dayOfWeek: 5, lessonIndex: 2, startTime: "08:55", endTime: "09:40", room: "204", teacher: "dr Jan Kowalski", breakAfterMinutes: 10),
            Lesson(subjectId: "s_wf",  dayOfWeek: 5, lessonIndex: 3, startTime: "09:50", endTime: "10:35", room: "Hala", teacher: "mgr Robert Lewandowski", breakAfterMinutes: 15),
            Lesson(subjectId: "s_ang", dayOfWeek: 5, lessonIndex: 4, startTime: "10:50", endTime: "11:35", room: "115", teacher: "mgr Sarah Brown", breakAfterMinutes: 10)
        ]

        // Przykładowe wydarzenia w planie
        self.events = [
            ScheduleEvent(subjectId: "s_mat", dayOfWeek: 1, lessonIndex: 2, title: "Funkcja wymierna", type: .sprawdzian, note: "Pamiętać o kalkulatorze prostym"),
            ScheduleEvent(subjectId: "s_ang", dayOfWeek: 3, lessonIndex: 1, title: "Słówka Unit 4", type: .kartkowka, note: "Strona 64-67")
        ]

        // Frekwencja miesięczna
        self.monthlyAttendance = [
            MonthlyAttendance(month: "Wrzesień", monthIndex: 1, percentage: 98.2),
            MonthlyAttendance(month: "Październik", monthIndex: 2, percentage: 94.0),
            MonthlyAttendance(month: "Listopad", monthIndex: 3, percentage: 89.5),
            MonthlyAttendance(month: "Grudzień", monthIndex: 4, percentage: 92.1),
            MonthlyAttendance(month: "Styczeń", monthIndex: 5, percentage: 95.8),
            MonthlyAttendance(month: "Luty", monthIndex: 6, percentage: 88.0),
            MonthlyAttendance(month: "Marzec", monthIndex: 7, percentage: 93.4),
            MonthlyAttendance(month: "Kwiecień", monthIndex: 8, percentage: 96.0),
            MonthlyAttendance(month: "Maj", monthIndex: 9, percentage: 91.5),
            MonthlyAttendance(month: "Czerwiec", monthIndex: 10, percentage: 97.0)
        ]

        // Wpisy frekwencji z poszczególnych lekcji
        var generatedAttendance: [AttendanceRecord] = []
        let sampleDates = [
            Date().addingTimeInterval(-86400 * 1),
            Date().addingTimeInterval(-86400 * 2),
            Date().addingTimeInterval(-86400 * 3),
            Date().addingTimeInterval(-86400 * 5),
            Date().addingTimeInterval(-86400 * 8),
            Date().addingTimeInterval(-86400 * 12)
        ]

        for s in subjects {
            generatedAttendance.append(AttendanceRecord(subjectId: s.id, date: sampleDates[0], status: .present, topic: "Lekcja organizacyjna i wstęp do działu"))
            generatedAttendance.append(AttendanceRecord(subjectId: s.id, date: sampleDates[1], status: .present, topic: "Ćwiczenia praktyczne i zadania"))
            generatedAttendance.append(AttendanceRecord(subjectId: s.id, date: sampleDates[2], status: .present, topic: "Powtórzenie materiału"))
        }
        // Kilka spóźnień i nieobecności
        generatedAttendance.append(AttendanceRecord(subjectId: "s_mat", date: sampleDates[3], status: .late, topic: "Wykresy funkcji"))
        generatedAttendance.append(AttendanceRecord(subjectId: "s_fiz", date: sampleDates[4], status: .lateExcused, topic: "Praca i moc"))
        generatedAttendance.append(AttendanceRecord(subjectId: "s_wf", date: sampleDates[5], status: .absentExcused, topic: "Gry zespołowe - siatkówka"))
        generatedAttendance.append(AttendanceRecord(subjectId: "s_bio", date: sampleDates[3], status: .absent, topic: "Układ nerwowy"))
        generatedAttendance.append(AttendanceRecord(subjectId: "s_his", date: sampleDates[4], status: .released, topic: "I Wojna Światowa"))

        self.attendanceRecords = generatedAttendance

        // Wiadomości
        self.messages = [
            SchoolMessage(
                sender: "mgr Anna Nowak (Wychowawca)",
                recipient: "Uczeń (Ty)",
                subject: "Informacja o zebraniu z rodzicami",
                body: "Dzień dobry,\n\nPrzypominam, że w najbliższy czwartek o godzinie 17:30 odbędzie się zebranie z rodzicami w sali 102.\nProszę przekazać informację rodzicom.\n\nPozdrawiam serdecznie,\nAnna Nowak",
                date: Date().addingTimeInterval(-3600 * 4),
                isRead: false
            ),
            SchoolMessage(
                sender: "dr Jan Kowalski",
                recipient: "Uczeń (Ty)",
                subject: "Wyniki sprawdzianu z matematyki",
                body: "Cześć,\n\nOceny ze sprawdzianu z funkcji zostały już wpisane do systemu. Gratuluję bardzo dobrych wyników!\nOsoby chętne do poprawy zapraszam w środę na 7 lekcji do sali 204.\n\nJan Kowalski",
                date: Date().addingTimeInterval(-86400 * 2),
                isRead: true
            ),
            SchoolMessage(
                sender: "Sekretariat Szkoły",
                recipient: "Wszyscy Uczniowie",
                subject: "Odbiór legitymacji szkolnych mLegitymacja",
                body: "Informujemy, że wnioski o przedłużenie mLegitymacji na kolejny rok szkolny można składać do końca tego tygodnia drogą elektroniczną lub w sekretariacie.",
                date: Date().addingTimeInterval(-86400 * 5),
                isRead: true
            )
        ]

        saveData()
    }
}

import Foundation
import SwiftUI

// MARK: - Przedmioty szkolne
public struct Subject: Identifiable, Codable, Hashable {
    public var id: String
    public var name: String
    public var teacher: String
    public var defaultRoom: String
    public var icon: String
    public var isHidden: Bool // Opcja ukrycia przedmiotu (np. Religia, WDŻ)

    public init(id: String = UUID().uuidString, name: String, teacher: String, defaultRoom: String, icon: String = "book.fill", isHidden: Bool = false) {
        self.id = id
        self.name = name
        self.teacher = teacher
        self.defaultRoom = defaultRoom
        self.icon = icon
        self.isHidden = isHidden
    }
}

// MARK: - Oceny
public struct Grade: Identifiable, Codable, Hashable {
    public var id: String
    public var subjectId: String
    public var value: Double // Wartość liczbowa: 1.0, 2.0, 3.5 (dla 3+), itp.
    public var displayValue: String // Wyświetlana: "5", "4+", "1", "6"
    public var weight: Int // Waga oceny: 1, 2, 3, 4, 5
    public var category: String // "Sprawdzian", "Kartkówka", "Odpowiedź", "Aktywność", "Projekt"
    public var date: Date
    public var comment: String

    public init(id: String = UUID().uuidString, subjectId: String, value: Double, displayValue: String, weight: Int, category: String, date: Date = Date(), comment: String = "") {
        self.id = id
        self.subjectId = subjectId
        self.value = value
        self.displayValue = displayValue
        self.weight = weight
        self.category = category
        self.date = date
        self.comment = comment
    }
}

// MARK: - Plan lekcji & Wydarzenia
public struct Lesson: Identifiable, Codable, Hashable {
    public var id: String
    public var subjectId: String
    public var dayOfWeek: Int // 1 = Poniedziałek ... 5 = Piątek
    public var lessonIndex: Int // Nr lekcji (1..8)
    public var startTime: String // "08:00"
    public var endTime: String   // "08:45"
    public var room: String
    public var teacher: String
    public var breakAfterMinutes: Int // Czas trwania przerwy po tej lekcji (np. 10 min)

    public init(id: String = UUID().uuidString, subjectId: String, dayOfWeek: Int, lessonIndex: Int, startTime: String, endTime: String, room: String, teacher: String, breakAfterMinutes: Int) {
        self.id = id
        self.subjectId = subjectId
        self.dayOfWeek = dayOfWeek
        self.lessonIndex = lessonIndex
        self.startTime = startTime
        self.endTime = endTime
        self.room = room
        self.teacher = teacher
        self.breakAfterMinutes = breakAfterMinutes
    }
}

public enum EventType: String, Codable, CaseIterable {
    case sprawdzian = "Sprawdzian"
    case kartkowka = "Kartkówka"
    case zadanieDomowe = "Zadanie domowe"
    case inne = "Inne wydarzenie"

    public var badgeColorName: String {
        switch self {
        case .sprawdzian: return "red"
        case .kartkowka: return "orange"
        case .zadanieDomowe: return "blue"
        case .inne: return "purple"
        }
    }
}

public struct ScheduleEvent: Identifiable, Codable, Hashable {
    public var id: String
    public var lessonId: String? // Przypisane do konkretnej lekcji
    public var subjectId: String
    public var dayOfWeek: Int // 1..5
    public var lessonIndex: Int
    public var title: String
    public var type: EventType
    public var date: Date
    public var note: String

    public init(id: String = UUID().uuidString, lessonId: String? = nil, subjectId: String, dayOfWeek: Int, lessonIndex: Int, title: String, type: EventType, date: Date = Date(), note: String = "") {
        self.id = id
        self.lessonId = lessonId
        self.subjectId = subjectId
        self.dayOfWeek = dayOfWeek
        self.lessonIndex = lessonIndex
        self.title = title
        self.type = type
        self.date = date
        self.note = note
    }
}

// MARK: - Frekwencja
public enum AttendanceStatus: String, Codable, CaseIterable {
    case present = "Obecność"
    case late = "Spóźnienie"
    case lateExcused = "Spóźnienie usprawiedliwione"
    case absent = "Nieobecność"
    case absentExcused = "Nieobecność usprawiedliwiona"
    case released = "Zwolnienie"

    public var isPositive: Bool {
        switch self {
        case .present, .late, .lateExcused, .released: return true
        case .absent, .absentExcused: return false
        }
    }

    public var badgeColor: Color {
        switch self {
        case .present: return .green
        case .late: return .orange
        case .lateExcused: return .yellow
        case .absent: return .red
        case .absentExcused: return .purple
        case .released: return .blue
        }
    }
}

public struct AttendanceRecord: Identifiable, Codable, Hashable {
    public var id: String
    public var subjectId: String
    public var date: Date
    public var status: AttendanceStatus
    public var topic: String

    public init(id: String = UUID().uuidString, subjectId: String, date: Date, status: AttendanceStatus, topic: String = "Temat zajęć") {
        self.id = id
        self.subjectId = subjectId
        self.date = date
        self.status = status
        self.topic = topic
    }
}

public struct MonthlyAttendance: Identifiable, Codable, Hashable {
    public var id: String { month }
    public var month: String // "Wrzesień", "Październik", itd.
    public var monthIndex: Int // 1..10
    public var percentage: Double // np. 94.5%

    public init(month: String, monthIndex: Int, percentage: Double) {
        self.month = month
        self.monthIndex = monthIndex
        self.percentage = percentage
    }
}

// MARK: - Wiadomości
public struct SchoolMessage: Identifiable, Codable, Hashable {
    public var id: String
    public var sender: String
    public var recipient: String
    public var subject: String
    public var body: String
    public var date: Date
    public var isRead: Bool
    public var isSentByUser: Bool

    public init(id: String = UUID().uuidString, sender: String, recipient: String = "Uczeń (Ty)", subject: String, body: String, date: Date = Date(), isRead: Bool = false, isSentByUser: Bool = false) {
        self.id = id
        self.sender = sender
        self.recipient = recipient
        self.subject = subject
        self.body = body
        self.date = date
        self.isRead = isRead
        self.isSentByUser = isSentByUser
    }
}

// MARK: - Customizacja & Ustawienia
public enum AppThemeColor: String, Codable, CaseIterable {
    case blue = "Niebieski (Librus)"
    case purple = "Fioletowy"
    case indigo = "Indygo"
    case emerald = "Szmaragdowy"
    case orange = "Miodowy Pomarańcz"
    case crimson = "Karmazynowy"

    public var color: Color {
        switch self {
        case .blue: return Color(red: 0.12, green: 0.45, blue: 0.90)
        case .purple: return Color(red: 0.60, green: 0.25, blue: 0.85)
        case .indigo: return Color(red: 0.35, green: 0.35, blue: 0.90)
        case .emerald: return Color(red: 0.10, green: 0.70, blue: 0.45)
        case .orange: return Color(red: 0.95, green: 0.50, blue: 0.15)
        case .crimson: return Color(red: 0.90, green: 0.20, blue: 0.35)
        }
    }
}

public struct NotificationSettings: Codable {
    public var isEnabled: Bool = true
    public var notifyGrades: Bool = true
    public var notifyMessages: Bool = true
    public var notifyExams: Bool = true
    public var notifyBreaks: Bool = false

    public init(isEnabled: Bool = true, notifyGrades: Bool = true, notifyMessages: Bool = true, notifyExams: Bool = true, notifyBreaks: Bool = false) {
        self.isEnabled = isEnabled
        self.notifyGrades = notifyGrades
        self.notifyMessages = notifyMessages
        self.notifyExams = notifyExams
        self.notifyBreaks = notifyBreaks
    }
}

import Foundation

public struct ParsedGradeItem {
    public var subjectName: String
    public var value: Double
    public var displayValue: String
    public var weight: Int
    public var category: String
    public var date: Date
    public var comment: String
}

public struct ParsedLessonItem {
    public var subjectName: String
    public var teacher: String
    public var room: String
    public var dayOfWeek: Int // 1..5
    public var lessonIndex: Int
    public var startTime: String
    public var endTime: String
    public var breakMinutes: Int
}

public struct ParsedAttendanceItem {
    public var subjectName: String
    public var date: Date
    public var status: AttendanceStatus
    public var topic: String
}

public struct ParsedMessageItem {
    public var sender: String
    public var subject: String
    public var date: Date
    public var body: String
    public var isRead: Bool
}

public final class LibrusHTMLParser {
    public static let shared = LibrusHTMLParser()
    private init() {}

    // MARK: - Parsowanie Danych Ucznia (/informacja)
    public func parseStudentInfo(html: String) -> (name: String, className: String, school: String)? {
        // Wyszukiwanie imienia i nazwiska oraz klasy w tabeli /informacja
        let namePattern = #"Imię i nazwisko[\s\S]*?<td[^>]*>([\s\S]*?)<\/td>"#
        let classPattern = #"Klasa[\s\S]*?<td[^>]*>([\s\S]*?)<\/td>"#
        let schoolPattern = #"Szkoła[\s\S]*?<td[^>]*>([\s\S]*?)<\/td>"#

        let name = extractFirstMatch(pattern: namePattern, text: html)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let className = extractFirstMatch(pattern: classPattern, text: html)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let school = extractFirstMatch(pattern: schoolPattern, text: html)?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let n = name, !n.isEmpty {
            return (
                cleanHTMLTags(n),
                cleanHTMLTags(className ?? "Klasa"),
                cleanHTMLTags(school ?? "Szkoła")
            )
        }
        return nil
    }

    // MARK: - Parsowanie Ocen (/przegladaj_oceny/uczen)
    public func parseGrades(html: String) -> [ParsedGradeItem] {
        var results: [ParsedGradeItem] = []

        // Podział na wiersze tabeli ocen
        let rowPattern = #"<tr[^>]*class="line[01]"[^>]*>([\s\S]*?)<\/tr>"#
        guard let rowRegex = try? NSRegularExpression(pattern: rowPattern, options: []) else { return [] }
        let nsHtml = html as NSString
        let rowMatches = rowRegex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length))

        for rowMatch in rowMatches {
            let rowContent = nsHtml.substring(with: rowMatch.range(at: 1))

            // Nazwa przedmiotu (zwykle w 2. kolumnie)
            let subjectPattern = #"<td[^>]*>([^<]+)<\/td>"#
            guard let subjectMatch = extractFirstMatch(pattern: subjectPattern, text: rowContent) else { continue }
            let subjectName = cleanHTMLTags(subjectMatch).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !subjectName.isEmpty && !subjectName.contains("Zachowanie") else { continue }

            // Wszystkie plakietki ocen w tym wierszu: <span class="grade-box"><a ... title="...">Wartość</a></span>
            let gradeBoxPattern = #"<span[^>]*class="[^"]*grade-box[^"]*"[^>]*>[\s\S]*?<a[^>]*title="([^"]*)"[^>]*>([\s\S]*?)<\/a>"#
            guard let gradeRegex = try? NSRegularExpression(pattern: gradeBoxPattern, options: []) else { continue }
            let nsRow = rowContent as NSString
            let gradeMatches = gradeRegex.matches(in: rowContent, options: [], range: NSRange(location: 0, length: nsRow.length))

            for gMatch in gradeMatches {
                let titleAttr = nsRow.substring(with: gMatch.range(at: 1))
                let displayVal = cleanHTMLTags(nsRow.substring(with: gMatch.range(at: 2))).trimmingCharacters(in: .whitespacesAndNewlines)

                let meta = parseGradeTooltip(titleAttr)
                let numVal = parseGradeNumericValue(displayVal)

                results.append(ParsedGradeItem(
                    subjectName: subjectName,
                    value: numVal,
                    displayValue: displayVal,
                    weight: meta.weight,
                    category: meta.category,
                    date: meta.date,
                    comment: meta.comment
                ))
            }
        }

        return results
    }

    // MARK: - Parsowanie Planu Lekcji (/przegladaj_plan_lekcji)
    public func parseTimetable(html: String) -> [ParsedLessonItem] {
        var lessons: [ParsedLessonItem] = []

        // Domyślne godziny lekcyjne w polskich szkołach (jeśli nie wyciągnięto z HTML)
        let defaultTimes = [
            1: ("08:00", "08:45", 10),
            2: ("08:55", "09:40", 10),
            3: ("09:50", "10:35", 15),
            4: ("10:50", "11:35", 20), // Przerwa obiadowa
            5: ("11:55", "12:40", 10),
            6: ("12:50", "13:35", 10),
            7: ("13:45", "14:30", 5),
            8: ("14:35", "15:20", 5)
        ]

        // Wiersze z numerami lekcji
        let rowPattern = #"<tr[^>]*>[\s\S]*?<td[^>]*class="center[^"]*"[^>]*>(\d+)<\/td>([\s\S]*?)<\/tr>"#
        guard let regex = try? NSRegularExpression(pattern: rowPattern, options: []) else { return [] }
        let nsHtml = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length))

        for match in matches {
            guard let lessonNum = Int(nsHtml.substring(with: match.range(at: 1))) else { continue }
            let cellsContent = nsHtml.substring(with: match.range(at: 2))

            // Kolumny dla dni tygodnia (Poniedziałek - Piątek, indeks 1..5)
            let cellPattern = #"<td[^>]*class="[^"]*plan-lekcji[^"]*"[^>]*>([\s\S]*?)<\/td>"#
            guard let cellRegex = try? NSRegularExpression(pattern: cellPattern, options: []) else { continue }
            let nsCells = cellsContent as NSString
            let cellMatches = cellRegex.matches(in: cellsContent, options: [], range: NSRange(location: 0, length: nsCells.length))

            for (dayIdx, cMatch) in cellMatches.enumerated() {
                let cellHtml = nsCells.substring(with: cMatch.range(at: 1))
                let text = cleanHTMLTags(cellHtml).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.isEmpty { continue }

                // W komórce Librusa jest zwykle: "Matematyka s.204 Kowalski J."
                let parts = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                let subjectName = parts.first ?? text
                var room = ""
                var teacher = ""

                for p in parts.dropFirst() {
                    if p.lowercased().contains("s.") || p.lowercased().contains("sala") {
                        room = p.replacingOccurrences(of: "s.", with: "").trimmingCharacters(in: .whitespaces)
                    } else if !p.isEmpty {
                        teacher = p.trimmingCharacters(in: .whitespaces)
                    }
                }

                let timeInfo = defaultTimes[lessonNum] ?? ("08:00", "08:45", 10)

                lessons.append(ParsedLessonItem(
                    subjectName: subjectName,
                    teacher: teacher,
                    room: room,
                    dayOfWeek: dayIdx + 1,
                    lessonIndex: lessonNum,
                    startTime: timeInfo.0,
                    endTime: timeInfo.1,
                    breakMinutes: timeInfo.2
                ))
            }
        }

        return lessons
    }

    // MARK: - Parsowanie Wiadomości (/wiadomosci)
    public func parseMessages(html: String) -> [ParsedMessageItem] {
        var messages: [ParsedMessageItem] = []

        // Wiersze wiadomości w tabeli
        let rowPattern = #"<tr[^>]*class="line[01]"[^>]*>([\s\S]*?)<\/tr>"#
        guard let regex = try? NSRegularExpression(pattern: rowPattern, options: []) else { return [] }
        let nsHtml = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: nsHtml.length))

        for match in matches {
            let rowContent = nsHtml.substring(with: match.range(at: 1))
            let tdPattern = #"<td[^>]*>([\s\S]*?)<\/td>"#
            guard let tdRegex = try? NSRegularExpression(pattern: tdPattern, options: []) else { continue }
            let nsRow = rowContent as NSString
            let tdMatches = tdRegex.matches(in: rowContent, options: [], range: NSRange(location: 0, length: nsRow.length))

            if tdMatches.count >= 4 {
                let sender = cleanHTMLTags(nsRow.substring(with: tdMatches[1].range(at: 1))).trimmingCharacters(in: .whitespacesAndNewlines)
                let subject = cleanHTMLTags(nsRow.substring(with: tdMatches[2].range(at: 1))).trimmingCharacters(in: .whitespacesAndNewlines)
                let dateStr = cleanHTMLTags(nsRow.substring(with: tdMatches[3].range(at: 1))).trimmingCharacters(in: .whitespacesAndNewlines)

                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let date = formatter.date(from: dateStr) ?? Date()

                let isRead = !rowContent.contains("bold")

                messages.append(ParsedMessageItem(
                    sender: sender.isEmpty ? "Nauczyciel" : sender,
                    subject: subject.isEmpty ? "(Brak tematu)" : subject,
                    date: date,
                    body: "Wiadomość z systemu Librus Synergia",
                    isRead: isRead
                ))
            }
        }

        return messages
    }

    // MARK: - Pomocnicze

    private func parseGradeTooltip(_ tooltip: String) -> (weight: Int, category: String, date: Date, comment: String) {
        // Format tooltipu w Librusie:
        // Ocena: 5<br/>Kategoria: Sprawdzian<br/>Data: 2026-10-14<br/>Waga: 3<br/>Komentarz: Dział 2
        var weight = 1
        var category = "Ocena bieżąca"
        var date = Date()
        var comment = ""

        let normalized = tooltip.replacingOccurrences(of: "<br/>", with: "\n")
            .replacingOccurrences(of: "<br>", with: "\n")
            .replacingOccurrences(of: "<br />", with: "\n")

        for line in normalized.components(separatedBy: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let key = parts[0].lowercased()
            let val = parts[1]

            if key.contains("waga") {
                weight = Int(val) ?? 1
            } else if key.contains("kategoria") {
                category = val
            } else if key.contains("data") {
                let df = DateFormatter()
                df.dateFormat = "yyyy-MM-dd"
                if let d = df.date(from: val) { date = d }
            } else if key.contains("komentarz") || key.contains("opis") {
                comment = val
            }
        }

        return (weight, category, date, comment)
    }

    private func parseGradeNumericValue(_ display: String) -> Double {
        let clean = display.replacingOccurrences(of: "*", with: "").trimmingCharacters(in: .whitespaces)
        if clean.contains("+") {
            let base = clean.replacingOccurrences(of: "+", with: "")
            return (Double(base) ?? 3.0) + 0.5
        } else if clean.contains("-") {
            let base = clean.replacingOccurrences(of: "-", with: "")
            return max((Double(base) ?? 3.0) - 0.25, 1.0)
        }
        return Double(clean) ?? 3.0
    }

    private func extractFirstMatch(pattern: String, text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let nsText = text as NSString
        guard let match = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) else { return nil }
        return nsText.substring(with: match.range(at: 1))
    }

    private func cleanHTMLTags(_ text: String) -> String {
        text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: nil)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}

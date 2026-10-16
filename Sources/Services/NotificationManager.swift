import Foundation
import UserNotifications

public final class NotificationManager {
    public static let shared = NotificationManager()

    private init() {}

    public func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    public func sendLocalNotification(title: String, body: String, delaySeconds: TimeInterval = 1, identifier: String = UUID().uuidString) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(delaySeconds, 1), repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Błąd powiadomienia: \(error.localizedDescription)")
            }
        }
    }

    public func scheduleExamReminder(title: String, subjectName: String, date: Date) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "Zbliża się \(title)"
        content.body = "Nie zapomnij o przygotowaniu z przedmiotu: \(subjectName)"
        content.sound = .default

        // Przypomnienie 1 dzień wcześniej o godzinie 17:00 lub za kilka sekund testowo
        let triggerDate = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "exam-\(UUID().uuidString)", content: content, trigger: trigger)
        center.add(request)
    }
}

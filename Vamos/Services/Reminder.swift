import Foundation
import UserNotifications

enum Reminder {
    private static let identifier = "vamos.daily"

    private static let messages = [
        "Un poquito cada día —— 每天一点点，今天的复习在等你。",
        "¡Vamos! 花五分钟复习一下今天的卡片吧。",
        "¿Qué tal? 今天还没练习西班牙语哦。",
        "连续学习别断了 🔥 打开 Vamos 练一课吧。"
    ]

    /// Asks for permission if needed, then schedules a daily reminder.
    static func schedule(hour: Int, minute: Int, completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            center.removePendingNotificationRequests(withIdentifiers: [identifier])

            let content = UNMutableNotificationContent()
            content.title = "该学西班牙语了"
            content.body = messages.randomElement() ?? messages[0]
            content.sound = .default

            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            center.add(request) { error in
                DispatchQueue.main.async { completion(error == nil) }
            }
        }
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}

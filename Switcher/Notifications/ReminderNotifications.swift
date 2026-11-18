import UserNotifications

/// Категорія сповіщень-нагадувань із кнопкою «Перемкнути».
enum ReminderNotifications {
    static let categoryID = "reminder"
    static let toggleActionID = "reminder.toggle"

    /// Кнопка «Перемкнути» спрацьовує без відкриття застосунку.
    static var category: UNNotificationCategory {
        let toggle = UNNotificationAction(identifier: toggleActionID, title: "Перемкнути", options: [])
        return UNNotificationCategory(identifier: categoryID, actions: [toggle], intentIdentifiers: [], options: [])
    }
}

/// Те, що `ReminderScheduler` використовує з центру сповіщень: у застосунку — `UNUserNotificationCenter`,
/// у тестах — фейк у пам'яті.
protocol ReminderNotificationCenter: AnyObject {
    func add(_ request: UNNotificationRequest) async throws
    func pendingNotificationRequests() async -> [UNNotificationRequest]
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) async
    func deliveredNotificationRequests() async -> [UNNotificationRequest]
    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) async
}

extension UNUserNotificationCenter: ReminderNotificationCenter {
    func deliveredNotificationRequests() async -> [UNNotificationRequest] {
        await deliveredNotifications().map(\.request)
    }
}

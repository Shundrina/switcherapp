import Foundation
import Observation
import UserNotifications

/// Центр сповіщень у пам'яті для тестового режиму (`-UITesting`): нічого не показує й не питає дозволу.
/// Заплановане видно екранним тестам через `PendingRemindersProbe`.
@Observable
final class InMemoryNotificationCenter: ReminderNotificationCenter {
    private struct Entry {
        let request: UNNotificationRequest
        let fireDate: Date
    }

    private var entries: [Entry] = []

    /// Тексти запланованих сповіщень у порядку спрацювання, через "\n"; порожньо, якщо нічого.
    var pendingBodies: String {
        entries.sorted { $0.fireDate < $1.fireDate }.map(\.request.content.body).joined(separator: "\n")
    }

    /// Як і справжній центр, запит із тим самим id замінює попередній.
    func add(_ request: UNNotificationRequest) {
        let interval = (request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? 0
        entries.removeAll { $0.request.identifier == request.identifier }
        entries.append(Entry(request: request, fireDate: .now.addingTimeInterval(interval)))
    }

    func pendingNotificationRequests() -> [UNNotificationRequest] {
        entries.map(\.request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        entries.removeAll { identifiers.contains($0.request.identifier) }
    }

    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}

    func deliveredNotificationRequests() -> [UNNotificationRequest] {
        []
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
}

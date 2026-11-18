import Foundation
import UserNotifications

/// Планує сповіщення-нагадування в центрі сповіщень за планом `ReminderPlanner`.
final class ReminderScheduler {
    private let center: any ReminderNotificationCenter
    /// Чи йде зараз перепланування; наступні виклики чекають у черзі `waiting`.
    private var isRescheduling = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(center: any ReminderNotificationCenter) {
        self.center = center
    }

    /// Прибирає наші заплановані запити й додає план для `items` — після кожної зміни стану чи правил
    /// і при відкритті застосунку. Одночасні виклики виконуються по черзі, і кожен бере стан перемикачів
    /// на момент, коли настала його черга, тож останнім у центрі лишається план найновішого стану.
    /// Якщо якийсь запит не вдалося додати, решта плану все одно додається, а перша помилка кидається
    /// в кінці.
    func reschedule(_ items: [SwitchItem], now: Date = .now, calendar: Calendar = .current) async throws {
        await waitForTurn()
        defer { passTurn() }

        // Масив могли взяти до видалення перемикача: видалений (ще не збережений — `isDeleted`,
        // уже збережений — без `modelContext`) у план не потрапляє, і його властивостей не читаємо.
        let snapshots = items
            .filter { !$0.isDeleted && $0.modelContext != nil }
            .map(ReminderSwitchSnapshot.init)
        let plan = ReminderPlanner.plan(for: snapshots, now: now, calendar: calendar)

        let stale = await center.pendingNotificationRequests()
            .filter { ReminderPayload(userInfo: $0.content.userInfo) != nil }
            .map(\.identifier)
        await center.removePendingNotificationRequests(withIdentifiers: stale)

        var firstError: (any Error)?
        for reminder in plan {
            let interval = reminder.date.timeIntervalSince(now)
            // Планувальник уже відкинув минуле; тригер з інтервалом ≤ 0 iOS не приймає.
            guard interval > 0 else { continue }
            do {
                try await center.add(Self.request(for: reminder, after: interval))
            } catch {
                firstError = firstError ?? error
            }
        }
        if let firstError { throw firstError }
    }

    /// Чекає, доки завершаться перепланування, викликані раніше.
    private func waitForTurn() async {
        guard isRescheduling else {
            isRescheduling = true
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Передає чергу наступному виклику (у порядку викликів) або звільняє її.
    private func passTurn() {
        if waiting.isEmpty {
            isRescheduling = false
        } else {
            waiting.removeFirst().resume()
        }
    }

    /// Прибирає вже показані сповіщення перемикача — після того, як його перемкнули.
    func removeDelivered(forSwitch switchID: UUID) async {
        let identifiers = await center.deliveredNotificationRequests()
            .filter { ReminderPayload(userInfo: $0.content.userInfo)?.switchID == switchID }
            .map(\.identifier)
        guard !identifiers.isEmpty else { return }
        await center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func request(for reminder: PlannedReminder, after interval: TimeInterval) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = reminder.body
        content.sound = .default
        content.userInfo = reminder.payload.userInfo
        content.categoryIdentifier = ReminderNotifications.categoryID
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        return UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger)
    }
}

import SwiftData
import SwiftUI
import UIKit
import UserNotifications

/// Спільні для застосунку сховище й нагадування. Один екземпляр на процес — у `AppDelegate`, бо дія
/// «Перемкнути» може прийти, коли застосунок запущено у фоні й жодного екрана ще немає.
final class AppServices {
    let container: ModelContainer
    let reminders: ReminderService
    /// Центр сповіщень у пам'яті — лише в тестовому режимі (для `PendingRemindersProbe`).
    let inMemoryCenter: InMemoryNotificationCenter?

    init(launchOptions: LaunchOptions) {
        do {
            // Звичайний запуск — сховище на диску; екранні тести (`-UITesting`) — лише в пам'яті,
            // тож файл сховища на диску не відкривається.
            let configuration = ModelConfiguration(isStoredInMemoryOnly: launchOptions.isStoredInMemoryOnly)
            container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
        } catch {
            fatalError("Не вдалося відкрити сховище: \(error)")
        }

        switch launchOptions.notifications {
        case .system:
            let center = UNUserNotificationCenter.current()
            inMemoryCenter = nil
            reminders = ReminderService(container: container, center: center, authorization: center)
        case .inMemory(let permission):
            let center = InMemoryNotificationCenter()
            inMemoryCenter = center
            reminders = ReminderService(
                container: container, center: center, authorization: FixedNotificationAuthorization(permission)
            )
        }
    }
}

/// Делегат застосунку: при запуску підключає нагадування й приймає відповіді на сповіщення.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    let services = AppServices(launchOptions: .current)

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Делегат треба призначити до кінця запуску: інакше відповідь на сповіщення, через яку
        // застосунок запустився у фоні, не дійде.
        if services.inMemoryCenter == nil {
            UNUserNotificationCenter.current().delegate = self
        }
        Task { await services.reminders.start() }
        return true
    }

    /// Застосунок відкритий — сповіщення все одно показується банером.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        ReminderNotifications.presentationOptions
    }

    /// Відповідь на сповіщення приходить не з головного потоку: з неї беруться прості значення,
    /// а сама дія виконується на головному акторі, де живе контекст сховища.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        guard let payload = ReminderPayload(userInfo: response.notification.request.content.userInfo) else { return }
        await handleResponse(actionIdentifier: actionIdentifier, payload: payload)
    }

    private func handleResponse(actionIdentifier: String, payload: ReminderPayload) async {
        await services.reminders.handleNotificationResponse(actionIdentifier: actionIdentifier, userInfo: payload.userInfo)
    }
}

/// Лише в тестовому режимі: невидимий елемент, `accessibilityValue` якого — тексти запланованих
/// сповіщень у порядку спрацювання. Натискань не перехоплює.
struct PendingRemindersProbe: View {
    let center: InMemoryNotificationCenter

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("Заплановані нагадування")
            .accessibilityValue(center.pendingBodies)
            .accessibilityIdentifier("pendingRemindersProbe")
    }
}

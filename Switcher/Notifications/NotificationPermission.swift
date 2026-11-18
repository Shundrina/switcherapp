import UserNotifications

/// Дозвіл на сповіщення так, як його бачить застосунок.
nonisolated enum NotificationPermission: Equatable, Sendable {
    /// Ще не питали — системне вікно покажеться при збереженні правила.
    case notDetermined
    case denied
    case allowed

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .denied: self = .denied
        case .authorized, .provisional, .ephemeral: self = .allowed
        @unknown default: self = .allowed
        }
    }

    /// Чи показувати «Сповіщення вимкнено» й «Відкрити Параметри».
    var showsDisabledNotice: Bool {
        self == .denied
    }
}

/// Дозвіл на сповіщення: у застосунку — `UNUserNotificationCenter`, у тестах — фейк.
protocol NotificationAuthorizing: AnyObject {
    /// Поточний дозвіл, без системного вікна.
    func permission() async -> NotificationPermission
    /// Показує системне вікно (якщо ще не питали) і повертає відповідь.
    func requestPermission() async -> NotificationPermission
}

extension UNUserNotificationCenter: NotificationAuthorizing {
    nonisolated func permission() async -> NotificationPermission {
        NotificationPermission(await notificationSettings().authorizationStatus)
    }

    nonisolated func requestPermission() async -> NotificationPermission {
        // Помилка запиту означає, що дозволу немає; що саме вирішено — покаже `permission()`.
        _ = try? await requestAuthorization(options: [.alert, .sound])
        return await permission()
    }
}

/// Дозвіл у тестовому режимі (`-UITesting`): заданий аргументом запуску, системне вікно не показується.
final class FixedNotificationAuthorization: NotificationAuthorizing {
    private let status: NotificationPermission

    init(_ status: NotificationPermission) {
        self.status = status
    }

    func permission() -> NotificationPermission {
        status
    }

    func requestPermission() -> NotificationPermission {
        status
    }
}

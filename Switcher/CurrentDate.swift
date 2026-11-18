import Combine
import SwiftUI
import UIKit

extension EnvironmentValues {
    /// Поточна мить і сигнал перерахувати всі тексти з датою й часом (зокрема після зміни поясу).
    /// Оновлюється модифікатором `tracksCurrentDate()`. View, що форматує дату чи час, має читати `\.now`
    /// або отримувати готовий текст від батьківського view, який його читає (як `EventRow`).
    @Entry var now: Date = .now
}

extension View {
    /// Передає вкладеним view поточну мить і оновлює її, коли настає новий день, змінюється
    /// часовий пояс чи системний час або застосунок повертається з фону. Щосекунди нічого не перераховується.
    func tracksCurrentDate() -> some View {
        modifier(CurrentDateModifier())
    }
}

/// Події, після яких поточну мить і всі тексти з датою й часом треба перерахувати, поки застосунок відкритий.
/// Системні сповіщення приходять і з фонових потоків, тож перетворення до `receive(on:)` не мають
/// бути прив'язані до головного актора.
nonisolated enum CurrentDateRefresh {
    /// Сповіщення: опівночі, зміна системного поясу, зміна системного часу (зокрема переведення годинника).
    static let notificationNames: [Notification.Name] = [
        .NSCalendarDayChanged,
        .NSSystemTimeZoneDidChange,
        UIApplication.significantTimeChangeNotification
    ]

    /// Спрацьовує на головному потоці щоразу, коли `center` публікує одне з `notificationNames`.
    /// Сповіщення може прийти не з головного потоку, тому доставка — через головну чергу.
    static func publisher(center: NotificationCenter = .default) -> AnyPublisher<Void, Never> {
        Publishers.MergeMany(notificationNames.map { center.publisher(for: $0) })
            .map { _ in }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
}

private struct CurrentDateModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now
    /// Один видавець на весь час життя модифікатора: новий при кожному перерахунку тіла змусив би
    /// SwiftUI перепідписуватися, і сповіщення, що прийшло в цей момент, могло б загубитися.
    @State private var refreshes = CurrentDateRefresh.publisher()

    func body(content: Content) -> some View {
        content
            .environment(\.now, now)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { refresh() }
            }
            .onReceive(refreshes) { _ in
                refresh()
            }
    }

    /// Системний пояс кешується до скидання: без нього `TimeZone.current` і `Calendar.current`
    /// після зміни поясу лишаються старими, і тексти перерахувалися б за попереднім поясом.
    private func refresh() {
        NSTimeZone.resetSystemTimeZone()
        now = .now
    }
}

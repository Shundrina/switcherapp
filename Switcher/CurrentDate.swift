import SwiftUI

extension EnvironmentValues {
    /// Поточна мить для текстів «сьогодні» і «вчора». Оновлюється модифікатором `tracksCurrentDate()`.
    @Entry var now: Date = .now
}

extension View {
    /// Передає вкладеним view поточну мить і оновлює її, коли настає новий день
    /// або застосунок повертається з фону. Щосекунди нічого не перераховується.
    func tracksCurrentDate() -> some View {
        modifier(CurrentDateModifier())
    }
}

private struct CurrentDateModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var now = Date.now

    func body(content: Content) -> some View {
        content
            .environment(\.now, now)
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { now = .now }
            }
            // Опівночі, поки застосунок відкритий. Сповіщення може прийти не з головного потоку.
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged).receive(on: DispatchQueue.main)) { _ in
                now = .now
            }
    }
}

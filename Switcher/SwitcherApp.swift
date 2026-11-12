import SwiftData
import SwiftUI

@main
struct SwitcherApp: App {
    private let launchOptions = LaunchOptions.current

    var body: some Scene {
        WindowGroup {
            RootView(onboarding: launchOptions.onboarding)
        }
        // Звичайний запуск — сховище на диску; екранні тести (`-UITesting`) — лише в пам'яті,
        // тож файл сховища на диску не відкривається.
        .modelContainer(for: SwitchItem.self, inMemory: launchOptions.isStoredInMemoryOnly)
    }
}

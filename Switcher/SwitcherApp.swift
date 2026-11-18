import SwiftData
import SwiftUI

@main
struct SwitcherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    private let launchOptions = LaunchOptions.current

    var body: some Scene {
        WindowGroup {
            RootView(onboarding: launchOptions.onboarding)
                .environment(appDelegate.services.reminders)
                .overlay(alignment: .topLeading) {
                    if let center = appDelegate.services.inMemoryCenter {
                        PendingRemindersProbe(center: center)
                    }
                }
        }
        // Той самий контейнер, що й у нагадувань: дія «Перемкнути» й екрани бачать ті самі дані.
        .modelContainer(appDelegate.services.container)
        .onChange(of: scenePhase) { _, phase in
            // Повернулися в застосунок: дозвіл могли змінити в Параметрах, час — піти вперед.
            if phase == .active {
                Task { await appDelegate.services.reminders.refresh() }
            }
        }
    }
}

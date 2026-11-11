import SwiftData
import SwiftUI

@main
struct SwitcherApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: SwitchItem.self)
    }
}

import SwiftUI

/// Показує онбординг на першому запуску, далі — список перемикачів.
struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            if hasSeenOnboarding {
                ContentView()
                    .tracksCurrentDate()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasSeenOnboarding = true
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

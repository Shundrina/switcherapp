import SwiftUI

/// Показує онбординг на першому запуску, далі — список перемикачів.
/// У тестовому режимі (`onboarding` не `.stored`) збережений прапорець не враховується й не записується.
struct RootView: View {
    var onboarding: LaunchOptions.Onboarding = .stored

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    /// Онбординг завершено в цьому запуску (не зберігається між запусками).
    @State private var hasFinishedOnboarding = false

    var body: some View {
        ZStack {
            if onboarding.showsList(hasSeenOnboarding: hasSeenOnboarding, finishedThisLaunch: hasFinishedOnboarding) {
                ContentView()
                    .tracksCurrentDate()
                    .transition(.opacity)
            } else {
                OnboardingView {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        hasFinishedOnboarding = true
                        if onboarding.persistsCompletion {
                            hasSeenOnboarding = true
                        }
                    }
                }
                .transition(.opacity)
            }
        }
    }
}

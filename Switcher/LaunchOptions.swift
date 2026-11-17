import Foundation

/// Режим запуску з аргументів процесу. Тестовий режим вмикається лише явно аргументом `-UITesting`
/// (його передають екранні тести); звичайний запуск працює зі сховищем на диску.
nonisolated struct LaunchOptions: Equatable {
    /// Звідки береться рішення, чи показувати онбординг.
    enum Onboarding: Equatable {
        /// За збереженим прапорцем `hasSeenOnboarding` у UserDefaults.
        case stored
        /// Не показувати; прапорець не враховується й не записується.
        case skipped
        /// Показати; прапорець не враховується й не записується.
        case shown
    }

    static let uiTestingArgument = "-UITesting"
    static let showOnboardingArgument = "-UITestingShowOnboarding"

    /// Сховище лише в пам'яті: порожнє на кожному запуску, дані користувача не зачіпає.
    let isStoredInMemoryOnly: Bool
    let onboarding: Onboarding
    /// Картка-зразок на екрані додавання сама вмикається й вимикається. У тестовому режимі — ні:
    /// натискання в сітках вибору, що припадали на цю анімацію, зрідка губилися в екранних тестах.
    let animatesAddPreview: Bool

    /// `arguments` — як у `ProcessInfo.processInfo.arguments`: перший елемент — шлях до програми.
    /// Аргументи порівнюються повністю, тож схожі рядки тестовий режим не вмикають.
    init(arguments: [String]) {
        let flags = Set(arguments.dropFirst())
        guard flags.contains(Self.uiTestingArgument) else {
            isStoredInMemoryOnly = false
            onboarding = .stored
            animatesAddPreview = true
            return
        }
        isStoredInMemoryOnly = true
        animatesAddPreview = false
        onboarding = flags.contains(Self.showOnboardingArgument) ? .shown : .skipped
    }

    /// Режим поточного процесу.
    static let current = LaunchOptions(arguments: ProcessInfo.processInfo.arguments)
}

nonisolated extension LaunchOptions.Onboarding {
    /// Чи показувати список замість онбордингу.
    /// - Parameters:
    ///   - hasSeenOnboarding: збережений прапорець (UserDefaults).
    ///   - finishedThisLaunch: онбординг завершено в поточному запуску.
    func showsList(hasSeenOnboarding: Bool, finishedThisLaunch: Bool) -> Bool {
        switch self {
        case .stored: hasSeenOnboarding || finishedThisLaunch
        case .skipped: true
        case .shown: finishedThisLaunch
        }
    }

    /// Чи записувати завершення онбордингу в збережений прапорець — лише у звичайному запуску.
    var persistsCompletion: Bool {
        self == .stored
    }
}

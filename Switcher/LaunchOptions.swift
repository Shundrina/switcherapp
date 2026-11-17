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

    /// Як поводиться картка-зразок «Вигляд у списку» на екрані додавання.
    enum AddPreview: Equatable {
        /// Відкривається вимкненою й далі сама вмикається й вимикається (крім Reduce Motion).
        case autoToggling
        /// Увімкнена весь час. Так кольорове тло розтікається за межі картки — найгірший для
        /// натискань стан, — і екранні тести ловлять натискання, які перехоплює картка, щоразу.
        case alwaysOn
    }

    static let uiTestingArgument = "-UITesting"
    static let showOnboardingArgument = "-UITestingShowOnboarding"

    /// Сховище лише в пам'яті: порожнє на кожному запуску, дані користувача не зачіпає.
    let isStoredInMemoryOnly: Bool
    let onboarding: Onboarding
    let addPreview: AddPreview

    /// `arguments` — як у `ProcessInfo.processInfo.arguments`: перший елемент — шлях до програми.
    /// Аргументи порівнюються повністю, тож схожі рядки тестовий режим не вмикають.
    init(arguments: [String]) {
        let flags = Set(arguments.dropFirst())
        guard flags.contains(Self.uiTestingArgument) else {
            isStoredInMemoryOnly = false
            onboarding = .stored
            addPreview = .autoToggling
            return
        }
        isStoredInMemoryOnly = true
        addPreview = .alwaysOn
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

nonisolated extension LaunchOptions.AddPreview {
    /// Чи картка увімкнена з самого відкриття екрана.
    var startsOn: Bool {
        self == .alwaysOn
    }

    /// Чи картка сама вмикається й вимикається.
    func togglesItself(reduceMotion: Bool) -> Bool {
        switch self {
        case .autoToggling: !reduceMotion
        case .alwaysOn: false
        }
    }
}

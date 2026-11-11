import Foundation

/// Сторінки онбордингу в порядку показу.
nonisolated enum OnboardingSlide: CaseIterable {
    case toggle, history, deletion

    var title: String {
        switch self {
        case .toggle: "Клац — і спокій"
        case .history: "Пам'ятає за вас"
        case .deletion: "Зайве — геть"
        }
    }

    var text: String {
        switch self {
        case .toggle: "Вимкнула праску? Зачинила двері? Перемкніть — і більше не сумнівайтеся."
        case .history: "Кожне перемикання зберігається з датою й часом. Історія завжди під рукою."
        case .deletion: "Перемикач більше не потрібен? Змахніть його ліворуч у списку. Перед видаленням застосунок перепитає."
        }
    }

    /// Остання сторінка: на ній замість «Далі» кнопка «Почати».
    var isLast: Bool {
        self == Self.allCases.last
    }
}

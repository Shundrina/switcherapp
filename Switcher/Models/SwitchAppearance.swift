import SwiftUI

nonisolated enum SwitchIcon: String, CaseIterable, Identifiable {
    case drop, flame, lock, pill, power, bell, clock, check

    var id: String { rawValue }

    /// Назва символу з SF Symbols.
    var symbolName: String {
        switch self {
        case .drop: "drop"
        case .flame: "flame"
        case .lock: "lock"
        case .pill: "pill"
        case .power: "power"
        case .bell: "bell"
        case .clock: "clock"
        case .check: "checkmark"
        }
    }

    var title: String {
        switch self {
        case .drop: "Крапля"
        case .flame: "Вогонь"
        case .lock: "Замок"
        case .pill: "Ліки"
        case .power: "Живлення"
        case .bell: "Дзвоник"
        case .clock: "Годинник"
        case .check: "Позначка"
        }
    }
}

/// Колір увімкненого перемикача. Усі кольори достатньо світлі для темного тексту.
nonisolated enum SwitchTone: String, CaseIterable, Identifiable {
    case amber, coral, mint, sky, lilac, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .amber: Color(hex: 0xFFC83D)
        case .coral: Color(hex: 0xFF8F70)
        case .mint: Color(hex: 0x5FD9A0)
        case .sky: Color(hex: 0x6FB6FF)
        case .lilac: Color(hex: 0xB9A2FF)
        case .pink: Color(hex: 0xFF9AD0)
        }
    }

    var title: String {
        switch self {
        case .amber: "Бурштин"
        case .coral: "Корал"
        case .mint: "М'ята"
        case .sky: "Небо"
        case .lilac: "Бузок"
        case .pink: "Рожевий"
        }
    }
}

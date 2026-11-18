import Foundation

/// Тексти сповіщень-нагадувань: «🔥 Газ горить» і «Увімкнено вже 30 хв».
nonisolated enum ReminderFormatting {
    /// Заголовок: «<емодзі> <назва>».
    static func title(icon: SwitchIcon, name: String) -> String {
        "\(icon.rawValue) \(name)"
    }

    /// «Увімкнено вже …», «Вимкнено вже …» або «Не перемикали вже …» — за умовою правила.
    static func body(condition: ReminderCondition, elapsed: String) -> String {
        let prefix = switch condition {
        case .on: "Увімкнено вже"
        case .off: "Вимкнено вже"
        case .always: "Не перемикали вже"
        }
        return "\(prefix) \(elapsed)"
    }

    /// Прожитий час для правил у хвилинах і годинах: «45 хв», «2 год», «2 год 10 хв». Хвилини понад 60
    /// переносяться в години; годин скільки завгодно, без днів.
    static func elapsed(hours: Int, minutes: Int) -> String {
        let hours = hours + minutes / 60
        let minutes = minutes % 60
        if hours == 0 { return "\(minutes) хв" }
        return minutes == 0 ? "\(hours) год" : "\(hours) год \(minutes) хв"
    }

    /// Прожитий час для правил у днях: «1 день», «3 дні», «5 днів».
    static func elapsed(days: Int) -> String {
        let lastTwo = days % 100
        let last = days % 10
        let word = if last == 1 && lastTwo != 11 {
            "день"
        } else if (2...4).contains(last) && !(12...14).contains(lastTwo) {
            "дні"
        } else {
            "днів"
        }
        return "\(days) \(word)"
    }
}

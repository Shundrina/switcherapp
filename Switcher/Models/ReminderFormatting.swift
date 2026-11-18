import Foundation

/// Тексти нагадувань: сповіщення («🔥 Газ горить», «Увімкнено вже 30 хв») і рядок правила
/// на екрані перемикача («Через 30 хв, коли увімкнено · повтор»).
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

    /// Прожитий час у сповіщенні правила, що прийшло вчасно: `amount` одиниць і ще `extraMinutes`
    /// для повтору. Для днів повтор не змінює тексту: «3 дні».
    static func elapsed(amount: Int, unit: ReminderUnit, extraMinutes: Int = 0) -> String {
        switch unit {
        case .minutes: elapsed(hours: 0, minutes: amount + extraMinutes)
        case .hours: elapsed(hours: amount, minutes: extraMinutes)
        case .days: elapsed(days: amount)
        }
    }

    /// Фактичний прожитий час від `start` до `end` (для запізнілого правила): для хвилин і годин —
    /// цілі хвилини, для днів — цілі календарні дні в поясі `calendar`.
    static func elapsed(from start: Date, to end: Date, unit: ReminderUnit, calendar: Calendar) -> String {
        switch unit {
        case .minutes, .hours:
            elapsed(hours: 0, minutes: Int(end.timeIntervalSince(start) / 60))
        case .days:
            elapsed(days: calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        }
    }

    /// Текст першого нагадування для прикладу сповіщення у вікні правила — той самий, що згенерує
    /// планувальник: «Увімкнено вже 1 год 30 хв».
    static func previewBody(condition: ReminderCondition, amount: Int, unit: ReminderUnit) -> String {
        body(condition: condition, elapsed: elapsed(amount: amount, unit: unit))
    }

    /// Рядок правила на екрані перемикача: «Через 90 хв, коли увімкнено», «Через 3 дні без перемикань»;
    /// з повтором — « · повтор». Число — як його ввели, без перерахунку в години.
    static func ruleSummary(condition: ReminderCondition, amount: Int, unit: ReminderUnit, repeats: Bool) -> String {
        let duration = switch unit {
        case .minutes: "\(amount) хв"
        case .hours: "\(amount) год"
        case .days: elapsed(days: amount)
        }
        let when = switch condition {
        case .on: ", коли увімкнено"
        case .off: ", коли вимкнено"
        case .always: " без перемикань"
        }
        return "Через \(duration)\(when)" + (repeats ? " · повтор" : "")
    }
}

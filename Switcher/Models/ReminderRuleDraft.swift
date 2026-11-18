import Foundation

/// Значення правила, які редагує вікно правила; у `ReminderRule` потрапляють лише після «Зберегти».
nonisolated struct ReminderRuleDraft: Equatable {
    /// Скільки хвилин, годин чи днів можна ввести (поле — до трьох цифр).
    static let amountRange = 1...999

    var condition: ReminderCondition = .on
    var amount = 30
    /// Зміна одиниці скидає повтор на типовий для неї (`ReminderUnit.repeatsByDefault`).
    var unit: ReminderUnit = .minutes {
        didSet {
            if unit != oldValue { repeats = unit.repeatsByDefault }
        }
    }
    var repeats = true

    /// Нове правило: «Коли увімкнено», через 30 хв, з повтором.
    init() {}

    /// Значення наявного правила; його повтор лишається, поки одиницю не змінили.
    init(rule: ReminderRule) {
        condition = rule.condition
        amount = rule.amount
        unit = rule.unit
        repeats = rule.repeats
    }

    var canSave: Bool {
        Self.amountRange.contains(amount)
    }

    /// Нове правило, створене й змінене в мить `date`.
    func makeRule(at date: Date) -> ReminderRule {
        ReminderRule(condition: condition, amount: amount, unit: unit, repeats: repeats, editedAt: date)
    }

    /// Записує значення в `rule`. `editedAt` оновлюється лише якщо щось змінилося: «Зберегти» без змін
    /// не повторює запізнілого нагадування.
    func apply(to rule: ReminderRule, at date: Date) {
        guard ReminderRuleDraft(rule: rule) != self else { return }
        rule.condition = condition
        rule.amount = amount
        rule.unit = unit
        rule.repeats = repeats
        rule.editedAt = date
    }
}

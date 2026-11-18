import Foundation
import SwiftData

/// Тип правила нагадування. Етап 2 додасть «у певний час».
nonisolated enum ReminderKind: String, Sendable {
    /// Минуло N хвилин, годин чи днів від останнього перемикання.
    case afterDuration
}

/// Коли правило діє: лише коли перемикач увімкнено, лише коли вимкнено, або завжди.
nonisolated enum ReminderCondition: String, Sendable {
    case on
    case off
    case always
}

/// Одиниця тривалості в правилі «через певний час».
nonisolated enum ReminderUnit: String, Sendable {
    case minutes
    case hours
    case days

    /// Повтор за замовчуванням: увімкнено для хвилин і годин, вимкнено для днів.
    var repeatsByDefault: Bool {
        self != .days
    }
}

/// Правило нагадування перемикача. Тип, умова й одиниця зберігаються сирими рядками, як значок
/// і колір перемикача; невідоме збережене значення читається як значення за замовчуванням нижче.
@Model
final class ReminderRule {
    /// Стабільний ідентифікатор — частина id запланованих сповіщень.
    var uuid: UUID = UUID()
    var kindRaw: String = "afterDuration"
    var conditionRaw: String = "always"
    var amount: Int = 1
    var unitRaw: String = "hours"
    /// Чи надсилати ще два нагадування через 10 і 20 хв після першого.
    var repeats: Bool = true
    var item: SwitchItem?

    /// `repeats`: не передано — за замовчуванням для одиниці (`ReminderUnit.repeatsByDefault`).
    init(condition: ReminderCondition, amount: Int, unit: ReminderUnit, repeats: Bool? = nil) {
        self.kindRaw = ReminderKind.afterDuration.rawValue
        self.conditionRaw = condition.rawValue
        self.amount = amount
        self.unitRaw = unit.rawValue
        self.repeats = repeats ?? unit.repeatsByDefault
    }

    /// Тип правила; невідоме збережене значення читається як «через певний час».
    var kind: ReminderKind {
        get { ReminderKind(rawValue: kindRaw) ?? .afterDuration }
        set { kindRaw = newValue.rawValue }
    }

    /// Умова правила; невідоме збережене значення читається як «завжди».
    var condition: ReminderCondition {
        get { ReminderCondition(rawValue: conditionRaw) ?? .always }
        set { conditionRaw = newValue.rawValue }
    }

    /// Одиниця тривалості; невідоме збережене значення читається як години.
    var unit: ReminderUnit {
        get { ReminderUnit(rawValue: unitRaw) ?? .hours }
        set { unitRaw = newValue.rawValue }
    }
}

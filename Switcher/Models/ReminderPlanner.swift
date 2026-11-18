import Foundation

/// Правило нагадування як просте значення — для планувальника, який не торкається SwiftData.
nonisolated struct ReminderRuleSnapshot: Equatable, Sendable {
    let id: UUID
    let condition: ReminderCondition
    let amount: Int
    let unit: ReminderUnit
    let repeats: Bool
}

/// Перемикач із правилами як просте значення — для планувальника.
nonisolated struct ReminderSwitchSnapshot: Equatable, Sendable {
    let id: UUID
    let name: String
    let icon: SwitchIcon
    let isOn: Bool
    let createdAt: Date
    let lastToggledAt: Date?
    let rules: [ReminderRuleSnapshot]
}

extension ReminderSwitchSnapshot {
    init(_ item: SwitchItem) {
        self.init(
            id: item.uuid, name: item.name, icon: item.icon, isOn: item.isOn,
            createdAt: item.createdAt, lastToggledAt: item.lastToggledAt,
            // Видалене, але ще не збережене правило може лишатися в `rules` — його не плануємо.
            rules: (item.rules ?? []).filter { !$0.isDeleted }.map { rule in
                ReminderRuleSnapshot(
                    id: rule.uuid, condition: rule.condition, amount: rule.amount, unit: rule.unit,
                    repeats: rule.repeats
                )
            }
        )
    }
}

/// Що сповіщення несе в `userInfo`: який перемикач і в якому стані він був при плануванні.
/// Дія «Перемкнути» ставить протилежний стан (див. `ReminderToggle`).
nonisolated struct ReminderPayload: Equatable, Sendable {
    let switchID: UUID
    let wasOn: Bool

    private static let switchIDKey = "switchID"
    private static let wasOnKey = "wasOn"

    init(switchID: UUID, wasOn: Bool) {
        self.switchID = switchID
        self.wasOn = wasOn
    }

    /// `nil` для чужого чи пошкодженого `userInfo`.
    init?(userInfo: [AnyHashable: Any]) {
        guard let idText = userInfo[Self.switchIDKey] as? String,
              let switchID = UUID(uuidString: idText),
              let wasOn = userInfo[Self.wasOnKey] as? Bool
        else { return nil }
        self.init(switchID: switchID, wasOn: wasOn)
    }

    /// Лише типи списку властивостей: UUID записано рядком.
    var userInfo: [AnyHashable: Any] {
        [Self.switchIDKey: switchID.uuidString, Self.wasOnKey: wasOn]
    }
}

/// Одне сповіщення, яке треба запланувати.
nonisolated struct PlannedReminder: Equatable, Sendable {
    /// Детермінований id запиту: перепланування замінює запит, а не дублює.
    let id: String
    let date: Date
    let title: String
    let body: String
    let payload: ReminderPayload
}

/// Що запланувати: чиста функція від знімків перемикачів, `now` і календаря.
nonisolated enum ReminderPlanner {
    /// Скільки сповіщень iOS тримає запланованими для застосунку.
    static let limit = 64
    /// Повтор: перше нагадування й ще два — через 10 і 20 хв.
    static let repeatCount = 3
    static let repeatIntervalMinutes = 10
    /// Найбільша кількість хвилин, годин чи днів у правилі; правило з більшою нічого не планує.
    static let maxAmount = 10_000

    /// Нагадування всіх правил усіх перемикачів, пізніші за `now`; якщо їх більше за `limit` —
    /// найраніші. Хвилини й години відраховуються абсолютним часом, дні — календарем
    /// (та сама година на годиннику в поясі `calendar`).
    static func plan(for switches: [ReminderSwitchSnapshot], now: Date = .now,
                     calendar: Calendar = .current) -> [PlannedReminder] {
        let reminders = switches.flatMap { item in
            item.rules.flatMap { rule in reminders(for: rule, of: item, calendar: calendar) }
        }
        return Array(
            reminders
                .filter { $0.date > now }
                .sorted { ($0.date, $0.id) < ($1.date, $1.id) }
                .prefix(limit)
        )
    }

    /// Перше нагадування правила й повтори, без огляду на `now`.
    private static func reminders(for rule: ReminderRuleSnapshot, of item: ReminderSwitchSnapshot,
                                  calendar: Calendar) -> [PlannedReminder] {
        guard (1...maxAmount).contains(rule.amount), applies(rule.condition, isOn: item.isOn) else { return [] }

        let reference = item.lastToggledAt ?? item.createdAt
        let firstDate: Date? = switch rule.unit {
        case .minutes: reference.addingTimeInterval(Double(rule.amount) * 60)
        case .hours: reference.addingTimeInterval(Double(rule.amount) * 3600)
        case .days: calendar.date(byAdding: .day, value: rule.amount, to: reference)
        }
        guard let firstDate else { return [] }

        let title = ReminderFormatting.title(icon: item.icon, name: item.name)
        let payload = ReminderPayload(switchID: item.id, wasOn: item.isOn)
        let count = rule.repeats ? repeatCount : 1

        return (0..<count).map { index in
            let extraMinutes = index * repeatIntervalMinutes
            let elapsed = switch rule.unit {
            case .minutes: ReminderFormatting.elapsed(hours: 0, minutes: rule.amount + extraMinutes)
            case .hours: ReminderFormatting.elapsed(hours: rule.amount, minutes: extraMinutes)
            case .days: ReminderFormatting.elapsed(days: rule.amount)
            }
            return PlannedReminder(
                id: "reminder.\(item.id.uuidString).\(rule.id.uuidString).\(index)",
                date: firstDate.addingTimeInterval(Double(extraMinutes) * 60),
                title: title,
                body: ReminderFormatting.body(condition: rule.condition, elapsed: elapsed),
                payload: payload
            )
        }
    }

    private static func applies(_ condition: ReminderCondition, isOn: Bool) -> Bool {
        switch condition {
        case .on: isOn
        case .off: !isOn
        case .always: true
        }
    }
}

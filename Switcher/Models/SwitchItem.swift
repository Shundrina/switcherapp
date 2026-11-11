import Foundation
import SwiftData

@Model
final class SwitchItem {
    var name: String = ""
    var isOn: Bool = false
    var createdAt: Date = Date.now
    var lastToggledAt: Date?
    var iconRaw: String = "check"
    var toneRaw: String = "amber"

    @Relationship(deleteRule: .cascade, inverse: \SwitchEvent.item)
    var events: [SwitchEvent]? = []

    init(name: String, icon: SwitchIcon = .check, tone: SwitchTone = .amber, createdAt: Date = .now) {
        self.name = name
        self.iconRaw = icon.rawValue
        self.toneRaw = tone.rawValue
        self.createdAt = createdAt
    }

    /// Значок перемикача; невідоме збережене значення читається як «позначка».
    var icon: SwitchIcon {
        get { SwitchIcon(rawValue: iconRaw) ?? .check }
        set { iconRaw = newValue.rawValue }
    }

    /// Колір перемикача; невідоме збережене значення читається як бурштиновий.
    var tone: SwitchTone {
        get { SwitchTone(rawValue: toneRaw) ?? .amber }
        set { toneRaw = newValue.rawValue }
    }

    /// Історія перемикань, найновіші спочатку.
    var sortedEvents: [SwitchEvent] {
        (events ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// Історія, згрупована за днями: найновіший день і найновіші події спочатку.
    func historyDays(calendar: Calendar = .current) -> [HistoryDay] {
        var days: [HistoryDay] = []
        for event in sortedEvents {
            let day = calendar.startOfDay(for: event.timestamp)
            if let last = days.last, last.date == day {
                days[days.count - 1].events.append(event)
            } else {
                days.append(HistoryDay(date: day, events: [event]))
            }
        }
        return days
    }

    /// Речення про останню зміну, наприклад «Увімкнено сьогодні о 08:15».
    func statusText(now: Date = .now, calendar: Calendar = .current) -> String {
        SwitchFormatting.status(isOn: isOn, lastToggledAt: lastToggledAt, now: now, calendar: calendar)
    }

    /// Зберігає назву з поля редагування (див. `SwitchName.forSaving`). Незмінений текст не чіпає
    /// назви — стара довга назва лишається повною; порожній після обрізання текст назви не змінює.
    /// Ту саму назву не присвоює повторно, щоб модель не позначалася зміненою.
    /// Історії, стану й вигляду не змінює.
    func rename(to text: String) {
        guard text != name else { return }
        let saved = SwitchName.forSaving(text)
        guard !saved.isEmpty, saved != name else { return }
        name = saved
    }

    /// Змінює стан і записує подію в історію; повторне встановлення того самого стану нічого не робить.
    func setOn(_ newValue: Bool, at date: Date = .now) {
        guard newValue != isOn else { return }
        isOn = newValue
        lastToggledAt = date

        let event = SwitchEvent(timestamp: date, isOn: newValue)
        event.item = self
        modelContext?.insert(event)
    }
}

/// Один день в історії перемикача.
nonisolated struct HistoryDay: Identifiable {
    /// Початок дня.
    let date: Date
    var events: [SwitchEvent]

    var id: Date { date }
}

import Foundation
import SwiftData

@Model
final class SwitchItem {
    var name: String = ""
    var isOn: Bool = false
    var createdAt: Date = Date.now
    var lastToggledAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \SwitchEvent.item)
    var events: [SwitchEvent]? = []

    init(name: String, createdAt: Date = .now) {
        self.name = name
        self.createdAt = createdAt
    }

    /// Історія перемикань, найновіші спочатку.
    var sortedEvents: [SwitchEvent] {
        (events ?? []).sorted { $0.timestamp > $1.timestamp }
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

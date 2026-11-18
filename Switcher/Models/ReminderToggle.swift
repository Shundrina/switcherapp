import Foundation
import SwiftData

/// Дія «Перемкнути» в сповіщенні.
enum ReminderToggle {
    /// Ставить перемикачу з `userInfo` стан, протилежний тому, що був при плануванні, — а не інвертує
    /// поточний: якщо стан уже змінили в застосунку, нічого не відбувається. Чуже `userInfo` і видалений
    /// перемикач ігноруються. Зміну одразу зберігає: застосунок у фоні можуть закрити будь-якої миті.
    static func perform(userInfo: [AnyHashable: Any], in context: ModelContext, at date: Date = .now) throws {
        guard let payload = ReminderPayload(userInfo: userInfo) else { return }
        let switchID = payload.switchID
        var descriptor = FetchDescriptor<SwitchItem>(predicate: #Predicate { $0.uuid == switchID })
        descriptor.fetchLimit = 1
        guard let item = try context.fetch(descriptor).first, item.isOn == payload.wasOn else { return }

        item.setOn(!payload.wasOn, at: date)
        try context.save()
    }
}

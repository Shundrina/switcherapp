import Foundation

/// Лагодження `SwitchItem.uuid`. Легка міграція SwiftData може дати всім наявним записам одне
/// значення за замовчуванням: перший власник UUID його зберігає, решта отримують нові.
nonisolated enum SwitchIdentity {
    /// Ті самі UUID у тому самому порядку, але кожен повтор після першого входження замінено новим,
    /// якого ще немає серед вхідних.
    static func repairingDuplicates(_ ids: [UUID]) -> [UUID] {
        var taken = Set(ids)
        var seen = Set<UUID>()
        return ids.map { id in
            if seen.insert(id).inserted { return id }
            var fresh = UUID()
            while taken.contains(fresh) { fresh = UUID() }
            taken.insert(fresh)
            return fresh
        }
    }

    /// Лагодить UUID перемикачів; «перший» — за порядком у масиві. Унікальних UUID не змінює.
    static func repairDuplicates(in items: [SwitchItem]) {
        let repaired = repairingDuplicates(items.map(\.uuid))
        for (item, uuid) in zip(items, repaired) where item.uuid != uuid {
            item.uuid = uuid
        }
    }
}

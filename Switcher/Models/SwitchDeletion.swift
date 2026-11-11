import Foundation
import SwiftData

/// Видалення перемикача: тексти підтвердження й сама операція.
nonisolated enum SwitchDeletion {
    static let confirmationMessage = "Історію перемикань теж буде видалено. Цю дію не можна скасувати."
    static let confirmButtonTitle = "Видалити"
    static let cancelButtonTitle = "Скасувати"

    /// «Видалити «Полила квіти»?»; для порожньої назви — «Видалити перемикач?».
    static func confirmationTitle(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Видалити перемикач?" : "Видалити «\(trimmed)»?"
    }

    /// Видаляє перемикач разом з історією (каскадно); зберігає зміни автозбереження контексту.
    static func delete(_ item: SwitchItem, from context: ModelContext) {
        context.delete(item)
    }
}

import Foundation

/// Назва перемикача: межа довжини, лічильник під полем і текст для збереження.
/// Довжина рахується в символах, які бачить людина (`Character`), а не в скалярах Unicode.
nonisolated enum SwitchName {
    static let maxLength = 30

    /// Текст для поля «Назва»: перші `maxLength` символів, пробіли по краях не чіпає.
    static func limited(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) : text
    }

    /// Що лишається в полі «Назва» після зміни тексту з `old` на `new`.
    /// У повне поле нові символи не вводяться — лишається `old`; вставка в неповне поле
    /// і будь-яка правка старої назви, довшої за межу, лишають перші `maxLength` символів.
    static func fieldText(from old: String, to new: String) -> String {
        if new.count <= maxLength { return new }
        return old.count == maxLength ? old : limited(new)
    }

    /// Що робить багаторядкове поле «Назва», коли текст змінюється з `old` на `new`.
    /// Якщо додано лише переноси рядка — це «Готово»: текст лишається `old`, редагування завершується.
    /// Переноси разом з іншим текстом (вставка, диктування) стають пробілами — кожна послідовність
    /// одним, — і редагування триває. Межу довжини застосовує `fieldText(from:to:)`.
    static func fieldEdit(from old: String, to new: String) -> (text: String, finishesEditing: Bool) {
        guard new.contains(where: \.isNewline) else {
            return (fieldText(from: old, to: new), false)
        }
        if new.filter({ !$0.isNewline }) == old { return (old, true) }

        var joined = ""
        var previousIsNewline = false
        for character in new {
            if character.isNewline {
                if !previousIsNewline { joined.append(" ") }
                previousIsNewline = true
            } else {
                joined.append(character)
                previousIsNewline = false
            }
        }
        return (fieldText(from: old, to: joined), false)
    }

    /// Назва для `SwitchItem`: без пробілів і переносів по краях, не довша за `maxLength`.
    static func forSaving(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Якщо межа припала на пробіл між словами, він не лишається в кінці.
        return String(trimmed.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// «12 / 30» — скільки символів у полі, разом із пробілами по краях.
    static func counterText(for text: String) -> String {
        "\(text.count) / \(maxLength)"
    }

    /// «Символів: 12 з 30» — те саме число для VoiceOver.
    static func counterAccessibilityLabel(for text: String) -> String {
        "Символів: \(text.count) з \(maxLength)"
    }
}

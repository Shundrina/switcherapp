import Foundation

/// Назва перемикача: межа довжини, лічильник під полем і текст для збереження.
/// Довжина рахується в символах, які бачить людина (`Character`), а не в скалярах Unicode.
nonisolated enum SwitchName {
    static let maxLength = 30

    /// Текст для поля «Назва»: перші `maxLength` символів, пробіли по краях не чіпає.
    static func limited(_ text: String) -> String {
        text.count > maxLength ? String(text.prefix(maxLength)) : text
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

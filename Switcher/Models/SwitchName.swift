import Foundation

/// Що робить делегат поля «Назва» чи «Примітка» з правкою, яку пропонує UIKit, — до того, як вона
/// потрапить у поле.
nonisolated enum SwitchNameEdit: Equatable, Sendable {
    /// Делегат повертає `true`: UIKit сам застосовує правку.
    case accept
    /// Делегат повертає `false`, сам ставить `text` і курсор на `cursor` (зсув UTF-16 від початку тексту).
    case replace(text: String, cursor: Int)
    /// Делегат повертає `false`: текст не змінюється.
    case reject
    /// «Готово» в полі редагування назви: текст не змінюється, редагування завершується.
    case finish
}

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
        forSaving(text, maxLength: maxLength)
    }

    /// Текст без пробілів і переносів по краях, не довший за `maxLength` (назва й примітка).
    fileprivate static func forSaving(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Якщо межа припала на пробіл між словами, він не лишається в кінці.
        return String(trimmed.prefix(maxLength)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// «12 / 30» — скільки символів у полі, разом із пробілами по краях.
    static func counterText(for text: String) -> String {
        "\(text.count) / \(maxLength)"
    }

    /// Чи довший текст за межу — так буває лише зі старою назвою, створеною до появи межі.
    /// Лічильник тоді виділяється: «Готово» збереже лише перші `maxLength` символів.
    static func isOverLimit(_ text: String) -> Bool {
        text.count > maxLength
    }

    /// «Символів: 12 з 30» — те саме число для VoiceOver; понад межу — з поясненням, що збережеться.
    static func counterAccessibilityLabel(for text: String) -> String {
        let label = "Символів: \(text.count) з \(maxLength)"
        return isOverLimit(text) ? "\(label). Після змін буде збережено лише перші \(maxLength)" : label
    }
}

/// Примітка до перемикача: межа довжини, лічильник під полем і текст для збереження.
/// Як `SwitchName`, але примітка багаторядкова: переноси рядка всередині — її частина (кожен — один
/// символ), а по краях обрізаються разом із пробілами. Порожня примітка — примітки немає.
nonisolated enum SwitchNote {
    static let maxLength = 200

    /// Примітка для `SwitchItem`: без пробілів і переносів по краях, не довша за `maxLength`.
    static func forSaving(_ text: String) -> String {
        SwitchName.forSaving(text, maxLength: maxLength)
    }

    /// «12 / 200» — скільки символів у полі, разом із пробілами й переносами.
    static func counterText(for text: String) -> String {
        "\(text.count) / \(maxLength)"
    }

    /// «Символів: 12 з 200» — те саме число для VoiceOver.
    static func counterAccessibilityLabel(for text: String) -> String {
        "Символів: \(text.count) з \(maxLength)"
    }

    /// Рішення делегата поля «Примітка» про правку — як `SwitchName.edit(_:range:replacement:allowsNewlineFinish:)`,
    /// але з межею `maxLength`, а переноси рядка лишаються як є: Return вставляє перенос, «Готово» не буває.
    static func edit(_ text: String, range: NSRange, replacement: String) -> SwitchNameEdit {
        SwitchName.edit(
            text, range: range, replacement: replacement,
            maxLength: maxLength, keepsNewlines: true, allowsNewlineFinish: false, keepsWordsWhole: true
        )
    }

    /// Правка в обхід делегата (складання IME, диктування) — як `SwitchName.edit(from:to:)`,
    /// але з межею `maxLength`, а переноси рядка лишаються як є.
    static func edit(from old: String, to new: String) -> SwitchNameEdit {
        SwitchName.edit(from: old, to: new, maxLength: maxLength, keepsNewlines: true)
    }
}

// MARK: - Правка в полі «Назва» чи «Примітка» до того, як вона потрапить у поле

nonisolated extension SwitchName {
    /// Рішення делегата поля «Назва» про правку: замінити `range` (одиниці UTF-16) у `text` на `replacement`.
    ///
    /// Результат не довший за `max(maxLength, text.count)` символів: правка, що не збільшує текст,
    /// приймається завжди (навіть у старій назві понад межу), а з вставки лишаються лише перші символи,
    /// які влазять. Виняток — правка, схожа на виправлення чи підказку одного слова (`isWordEdit`):
    /// вона застосовується вся або `.reject`, дозволено лише відкинути її кінцевий пробіл.
    /// Діапазон, що ріже символ (емодзі) навпіл, розширюється до меж символу.
    /// Переноси рядка у вставці стають пробілами — кожна послідовність одним; якщо `allowsNewlineFinish`,
    /// заміна з самих переносів — це «Готово». Некоректний діапазон — `.reject`.
    static func edit(_ text: String, range: NSRange, replacement: String, allowsNewlineFinish: Bool) -> SwitchNameEdit {
        edit(
            text, range: range, replacement: replacement,
            maxLength: maxLength, keepsNewlines: false, allowsNewlineFinish: allowsNewlineFinish, keepsWordsWhole: true
        )
    }

    /// Спільне для назви й примітки: межа `maxLength`; `keepsNewlines` — переноси рядка у вставці
    /// лишаються як є (примітка), а не стають пробілами; `keepsWordsWhole: false` — без винятку
    /// для одного слова: вставка завжди обрізається.
    fileprivate static func edit(
        _ text: String, range: NSRange, replacement: String,
        maxLength: Int, keepsNewlines: Bool, allowsNewlineFinish: Bool, keepsWordsWhole: Bool
    ) -> SwitchNameEdit {
        let source = text as NSString
        let length = source.length
        guard range.location >= 0, range.length >= 0,
              range.location <= length, range.length <= length - range.location
        else { return .reject }

        if allowsNewlineFinish, !replacement.isEmpty, replacement.allSatisfy(\.isNewline) {
            return .finish
        }

        // Межі діапазону — по межах символів: курсор усередині символу стає після нього,
        // виділення розширюється до цілих символів.
        var target = range
        var isSnapped = false
        if target.location < length {
            let character = source.rangeOfComposedCharacterSequence(at: target.location)
            if character.location != target.location {
                if target.length == 0 {
                    target.location = NSMaxRange(character)
                } else {
                    target.length += target.location - character.location
                    target.location = character.location
                }
                isSnapped = true
            }
        }
        if target.length > 0, NSMaxRange(target) < length {
            let character = source.rangeOfComposedCharacterSequence(at: NSMaxRange(target))
            if character.location != NSMaxRange(target) {
                target.length = NSMaxRange(character) - target.location
                isSnapped = true
            }
        }

        let joinsNewlines = !keepsNewlines && replacement.contains(where: \.isNewline)
        let insertion = joinsNewlines ? joiningNewlines(replacement) : replacement
        let prefix = source.substring(to: target.location)
        let suffix = source.substring(from: NSMaxRange(target))
        let limit = max(maxLength, text.count)

        // Виправлення чи підказка одного слова («квти» → «квіти», «кух» → «Кухні », наступне слово
        // «кухні ») — усе або нічого: обрізане слово гірше за незмінене.
        if keepsWordsWhole, isWordEdit(replacing: source.substring(with: target), with: insertion) {
            if (prefix + insertion + suffix).count <= limit {
                if !isSnapped, !joinsNewlines { return .accept }
                return .replace(text: prefix + insertion + suffix, cursor: target.location + (insertion as NSString).length)
            }
            // Кінцевий пробіл можна відкинути, якщо без нього слово влазить.
            if insertion.last == " " {
                let word = String(insertion.dropLast())
                if (prefix + word + suffix).count <= limit {
                    return .replace(text: prefix + word + suffix, cursor: target.location + (word as NSString).length)
                }
            }
            return .reject
        }

        // Скільки перших символів вставки влазить. Символи на стиках можуть зливатися
        // (комбіновані знаки), тож рахуємо готовий текст; перевіряти більше ніж на 2 символи
        // понад вільне місце немає сенсу — так довга вставка не перебирається повністю.
        let room = max(0, limit - prefix.count - suffix.count)
        var fitting = min(insertion.count, room + 2)
        while fitting > 0, (prefix + insertion.prefix(fitting) + suffix).count > limit {
            fitting -= 1
        }
        let inserted = String(insertion.prefix(fitting))

        if fitting == insertion.count, !isSnapped, !joinsNewlines { return .accept }
        if inserted.isEmpty, target.length == 0 { return .reject }
        return .replace(text: prefix + inserted + suffix, cursor: target.location + (inserted as NSString).length)
    }

    /// Правка, яка перетворила `old` на `new` в обхід делегата (складання IME, диктування), —
    /// як рішення `edit(_:range:replacement:allowsNewlineFinish:)` для `old`: змінений шматок
    /// шукається між спільним початком і спільним кінцем. Переноси стають пробілами, «Готово» немає.
    /// Відповідь — лише `.accept` (лишити `new`) або `.replace`: якщо не влазить нічого,
    /// повертається `old` з курсором там, де була правка.
    static func edit(from old: String, to new: String) -> SwitchNameEdit {
        edit(from: old, to: new, maxLength: maxLength, keepsNewlines: false)
    }

    /// Спільне для назви й примітки: межа `maxLength`; `keepsNewlines` — переноси лишаються як є.
    fileprivate static func edit(from old: String, to new: String, maxLength: Int, keepsNewlines: Bool) -> SwitchNameEdit {
        let oldCharacters = Array(old)
        let newCharacters = Array(new)
        let common = min(oldCharacters.count, newCharacters.count)
        var head = 0
        while head < common, oldCharacters[head] == newCharacters[head] { head += 1 }
        var tail = 0
        while tail < common - head,
              oldCharacters[oldCharacters.count - 1 - tail] == newCharacters[newCharacters.count - 1 - tail] {
            tail += 1
        }
        let range = NSRange(
            location: String(oldCharacters[..<head]).utf16.count,
            length: String(oldCharacters[head..<(oldCharacters.count - tail)]).utf16.count
        )
        let replacement = String(newCharacters[head..<(newCharacters.count - tail)])
        // Різниця двох текстів нічого не каже про намір, тож без винятку для одного слова — лише обрізання.
        let result = edit(
            old, range: range, replacement: replacement,
            maxLength: maxLength, keepsNewlines: keepsNewlines, allowsNewlineFinish: false, keepsWordsWhole: false
        )
        return result == .reject ? .replace(text: old, cursor: range.location) : result
    }

    /// Чи схожа правка на виправлення чи підказку одного слова:
    /// - замінюється непорожній шматок без пробільних символів, а заміна без кінцевого пробілу —
    ///   одне слово без пробільних символів (автовиправлення, підказка-доповнення, слово поверх слова);
    /// - або нічого не замінюється, а заміна — одне слово з кінцевим пробілом (підказка наступного слова).
    private static func isWordEdit(replacing replaced: String, with insertion: String) -> Bool {
        let word = insertion.last == " " ? insertion.dropLast() : Substring(insertion)
        guard !word.isEmpty, !word.contains(where: \.isWhitespace) else { return false }
        if replaced.isEmpty { return insertion.last == " " }
        return !replaced.contains(where: \.isWhitespace)
    }

    /// Кожна послідовність переносів рядка — один пробіл.
    private static func joiningNewlines(_ text: String) -> String {
        var joined = ""
        var previousIsNewline = false
        for character in text {
            if character.isNewline {
                if !previousIsNewline { joined.append(" ") }
                previousIsNewline = true
            } else {
                joined.append(character)
                previousIsNewline = false
            }
        }
        return joined
    }
}

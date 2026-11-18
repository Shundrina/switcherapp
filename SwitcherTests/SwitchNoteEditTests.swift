import Foundation
import Testing
@testable import Switcher

// Рішення делегата поля «Примітка» (на екрані додавання й на екрані перемикача) про правку ДО того,
// як вона потрапить у поле: `SwitchNote.edit(_:range:replacement:)` і, для правок в обхід делегата
// (складання IME, диктування), `SwitchNote.edit(from:to:)`. Відповідь — той самий `SwitchNameEdit`,
// що й для назви.
//
// Обмеження — як у назви (див. `SwitchNameEditTests`, `SwitchNameEditFromToTests`), лише межа 200:
// у повне поле нові символи не вводяться, з вставки лишаються перші символи, які влазять, емодзі
// не розрізаються, виправлення одного слова — усе або нічого.
//
// Відмінність від назви — примітка багаторядкова:
// - Return на клавіатурі вставляє перенос рядка, а не завершує редагування (`.finish` не буває —
//   редагування завершує кнопка «Готово» над клавіатурою);
// - переноси рядка у вставці лишаються як є (не стають пробілами);
// - перенос — один символ у межі 200 (і «\r\n» теж: це один `Character`).
//
// Тут лише те, що залежить від межі 200 і від переносів; решту правил покривають тести назви —
// реалізація має бути спільною (той самий алгоритм з параметром межі й поведінки переносів).

/// Повне поле: рівно 200 символів (усі в BMP, тож UTF-16 — теж 200).
private let full200 = String(repeating: "Полила квіти. ", count: 14) + "Газ!"
/// На один символ менше за межу.
private let almost199 = String(full200.dropLast())
/// 200 символів з одруком «квти» (UTF-16: 189..<193).
private let typo200 = String(repeating: "Полила квіти. ", count: 13) + "Полила квти. " + "Газ!!"
/// Сім'я з ZWJ: 1 символ, 8 одиниць UTF-16.
private let family = "👨‍👩‍👧"
/// Прапор: 1 символ, 4 одиниці UTF-16.
private let flag = "🇺🇦"

private func utf16Length(_ text: String) -> Int { (text as NSString).length }

private func endOf(_ text: String) -> NSRange { NSRange(location: utf16Length(text), length: 0) }

/// Що опиниться в полі після відповіді делегата; `nil` — `.finish`, якого в примітці не буває.
private func fieldText(after edit: SwitchNameEdit, text: String, range: NSRange, replacement: String) -> String? {
    switch edit {
    case .accept: (text as NSString).replacingCharacters(in: range, with: replacement)
    case .replace(let newText, _): newText
    case .reject: text
    case .finish: nil
    }
}

@MainActor
struct SwitchNoteEditTests {
    @Test func fixturesHaveExpectedLengths() {
        #expect(full200.count == 200 && utf16Length(full200) == 200)
        #expect(almost199.count == 199 && utf16Length(almost199) == 199)
        #expect(typo200.count == 200 && (typo200 as NSString).substring(with: NSRange(location: 189, length: 4)) == "квти")
        #expect(family.count == 1 && utf16Length(family) == 8)
    }

    // MARK: - Межа 200

    @Test func typingIntoEmptyFieldIsAccepted() {
        #expect(SwitchNote.edit("", range: endOf(""), replacement: "П") == .accept)
    }

    // 199 → 200 приймається (зсув межі на −1 цей тест ламає).
    @Test func typingTheTwoHundredthCharacterIsAccepted() {
        #expect(SwitchNote.edit(almost199, range: endOf(almost199), replacement: "!") == .accept)
    }

    // Межа назви (30) тут не діє: 31-й символ приймається.
    @Test func typingBeyondTheNameLimitIsAccepted() {
        let text = String(full200.prefix(30))
        #expect(SwitchNote.edit(text, range: endOf(text), replacement: "я") == .accept)
    }

    // 200 → 201 відкидається (зсув межі на +1 цей тест ламає).
    @Test(arguments: [0, 100, 200])
    func typingIntoFullFieldIsRejected(cursor: Int) {
        #expect(SwitchNote.edit(full200, range: NSRange(location: cursor, length: 0), replacement: "я") == .reject)
    }

    @Test(arguments: [family, flag])
    func emojiIntoFullFieldIsRejected(emoji: String) {
        #expect(SwitchNote.edit(full200, range: endOf(full200), replacement: emoji) == .reject)
    }

    // Емодзі як 200-й символ приймається: рахуються символи, а не одиниці UTF-16.
    @Test(arguments: [family, flag])
    func emojiAsTwoHundredthCharacterIsAccepted(emoji: String) {
        #expect(SwitchNote.edit(almost199, range: endOf(almost199), replacement: emoji) == .accept)
    }

    // З двох емодзі влазить лише перше — ціле; курсор після нього (у UTF-16).
    @Test func emojiPasteAtTheLimitKeepsWholeCharacters() {
        let edit = SwitchNote.edit(almost199, range: endOf(almost199), replacement: family + family)
        #expect(edit == .replace(text: almost199 + family, cursor: 199 + 8))
    }

    // Вставка, що не влазить: лишаються її перші символи, курсор після вставленого.
    @Test func pasteOverTheLimitInsertsOnlyWhatFits() {
        let text = String(full200.prefix(190))
        let edit = SwitchNote.edit(text, range: endOf(text), replacement: "у вітальні й на кухні")
        #expect(edit == .replace(text: text + "у вітальні", cursor: 200))
    }

    // Вставка в середину: обрізається вставка, а не хвіст наявного тексту.
    @Test func longPasteInTheMiddleKeepsTheTailOfExistingText() {
        let text = String(full200.prefix(195)) // курсор після «Полила » (UTF-16: 7)
        let edit = SwitchNote.edit(text, range: NSRange(location: 7, length: 0), replacement: "усі вазони ")
        let expected = "Полила усі в" + String(text.dropFirst(7))
        #expect(expected.count == 200)
        #expect(edit == .replace(text: expected, cursor: 12))
    }

    @Test func longPasteIntoEmptyFieldKeepsFirstTwoHundredCharacters() {
        let edit = SwitchNote.edit("", range: endOf(""), replacement: full200 + " і ще трохи")
        #expect(edit == .replace(text: full200, cursor: 200))
    }

    @Test func deletingFromFullFieldIsAccepted() {
        #expect(SwitchNote.edit(full200, range: NSRange(location: 199, length: 1), replacement: "") == .accept)
        #expect(SwitchNote.edit(full200, range: NSRange(location: 0, length: 200), replacement: "") == .accept)
    }

    // Автовиправлення «квти» → «квіти» у повному полі — усе або нічого: не влазить, тож текст не змінюється.
    @Test func autocorrectToLongerWordInFullFieldIsRejected() {
        #expect(SwitchNote.edit(typo200, range: NSRange(location: 189, length: 4), replacement: "квіти") == .reject)
    }

    // Те саме виправлення в тексті на 199 символів влазить — UIKit застосовує його сам.
    @Test func autocorrectThatFitsIsAccepted() throws {
        let text = String(typo200.dropLast())
        try #require(text.count == 199)
        #expect(SwitchNote.edit(text, range: NSRange(location: 189, length: 4), replacement: "квіти") == .accept)
    }

    @Test(arguments: [
        NSRange(location: 14, length: 0), // за кінцем
        NSRange(location: 12, length: 2),
        NSRange(location: NSNotFound, length: 0),
        NSRange(location: -1, length: 1),
        NSRange(location: 2, length: -1)
    ])
    func invalidRangeIsRejected(range: NSRange) {
        let text = "Полила квіти." // UTF-16: 13
        #expect(SwitchNote.edit(text, range: range, replacement: "и") == .reject)
        #expect(SwitchNote.edit(text, range: range, replacement: "\n") == .reject)
    }

    // MARK: - Переноси рядка: Return вставляє перенос, вставка зберігає переноси

    // Return у будь-якому місці вставляє перенос; редагування не завершується.
    @Test(arguments: [("", 0), ("Полити вазони", 13), ("Полити вазони", 6), ("Полити вазони", 0)] as [(String, Int)])
    func returnKeyInsertsNewline(text: String, location: Int) throws {
        let range = NSRange(location: location, length: 0)
        let edit = SwitchNote.edit(text, range: range, replacement: "\n")
        #expect(edit != .finish)
        let result = try #require(fieldText(after: edit, text: text, range: range, replacement: "\n"))
        #expect(result == (text as NSString).replacingCharacters(in: range, with: "\n"))
        if case .replace(_, let cursor) = edit {
            #expect(cursor == location + 1)
        }
    }

    // Return поверх виділення замінює виділене переносом — як у звичайному багаторядковому полі.
    @Test func returnKeyOverSelectionReplacesIt() throws {
        let text = "Полити вазони"
        let range = NSRange(location: 6, length: 1) // пробіл
        let edit = SwitchNote.edit(text, range: range, replacement: "\n")
        #expect(try #require(fieldText(after: edit, text: text, range: range, replacement: "\n")) == "Полити\nвазони")
    }

    // Перенос — один символ: 199 → 200 приймається, у повне поле — ні.
    @Test func returnKeyAsTwoHundredthCharacterIsInserted() throws {
        let edit = SwitchNote.edit(almost199, range: endOf(almost199), replacement: "\n")
        #expect(try #require(fieldText(after: edit, text: almost199, range: endOf(almost199), replacement: "\n")) == almost199 + "\n")
    }

    @Test(arguments: ["\n", "\r\n", "\n\n"], [0, 100, 200])
    func newlineIntoFullFieldIsRejected(newline: String, cursor: Int) {
        #expect(SwitchNote.edit(full200, range: NSRange(location: cursor, length: 0), replacement: newline) == .reject)
    }

    // «\r\n» (апаратна клавіатура, вставка з Windows) — теж один символ, і лишається як є.
    @Test func crlfAsTwoHundredthCharacterIsInsertedAsIs() throws {
        let edit = SwitchNote.edit(almost199, range: endOf(almost199), replacement: "\r\n")
        let result = try #require(fieldText(after: edit, text: almost199, range: endOf(almost199), replacement: "\r\n"))
        #expect(result == almost199 + "\r\n")
        #expect(result.count == 200)
    }

    // Вставка з переносами — як є (переноси не стають пробілами, послідовності не зливаються).
    @Test(arguments: [
        ("", 0, "Полити\nвазони"),
        ("", 0, "Полити\r\nвазони"),
        ("", 0, "Полити\n\n\nвазони\n"),
        ("Полити", 6, "\nвазони"),
        ("вазони", 0, "Полити\n"),
        ("Газ", 3, "\n\nгорить\n")
    ] as [(String, Int, String)])
    func pasteWithNewlinesIsKeptAsIs(text: String, location: Int, paste: String) throws {
        let range = NSRange(location: location, length: 0)
        let edit = SwitchNote.edit(text, range: range, replacement: paste)
        let expected = (text as NSString).replacingCharacters(in: range, with: paste)
        #expect(try #require(fieldText(after: edit, text: text, range: range, replacement: paste)) == expected)
        if case .replace(_, let cursor) = edit {
            #expect(cursor == location + utf16Length(paste))
        }
    }

    // Вставка з переносами, що не влазить: перші символи вставки разом з переносами, кожен — один символ.
    @Test func pasteWithNewlinesOverTheLimitKeepsItsFirstCharacters() {
        let text = String(full200.prefix(190))
        let edit = SwitchNote.edit(text, range: endOf(text), replacement: "\nКухня:\nвазон")
        #expect(edit == .replace(text: text + "\nКухня:\nва", cursor: 200))
    }

    // MARK: - Інваріант: результат будь-якої правки не довший за 200, «Готово» не буває

    @Test(arguments: [
        ("", full200 + full200),
        (almost199, family + flag + "абв"),
        (full200, "абв"),
        (String(full200.prefix(150)), "абв\nгде\r\n" + String(repeating: "ж", count: 60)),
        ("Полила", String(repeating: family, count: 250))
    ])
    func noEditGrowsTextBeyondTheLimit(text: String, paste: String) throws {
        for location in 0...utf16Length(text) {
            let range = NSRange(location: location, length: 0)
            let edit = SwitchNote.edit(text, range: range, replacement: paste)
            let result = try #require(fieldText(after: edit, text: text, range: range, replacement: paste), "location \(location): .finish")
            #expect(result.count <= 200, "location \(location): \(result.count) символів")
            if case .replace(let newText, let cursor) = edit {
                #expect((0...utf16Length(newText)).contains(cursor), "location \(location): курсор \(cursor)")
            }
        }
    }
}

/// Правка в обхід делегата (складання IME, диктування): `SwitchNote.edit(from:to:)`.
/// Як `SwitchName.edit(from:to:)`: відповідь — `.accept` (лишити `to`) або `.replace`;
/// межа 200; переноси рядка лишаються як є.
@MainActor
struct SwitchNoteEditFromToTests {
    /// Що опиниться в полі; `nil` — відповідь, якої тут бути не може.
    private func fieldText(after edit: SwitchNameEdit, new: String) -> String? {
        switch edit {
        case .accept: new
        case .replace(let text, _): text
        case .reject, .finish: nil
        }
    }

    @Test(arguments: [
        ("", "Полити вазони"),
        ("Полити", "Полити вазони"),
        (String(full200.prefix(30)), String(full200.prefix(31))),
        (almost199, full200)
    ])
    func compositionThatFitsIsAccepted(old: String, new: String) {
        #expect(SwitchNote.edit(from: old, to: new) == .accept)
    }

    @Test(arguments: [
        ("Полити", "Полити\nвазони"),
        ("", "Рядок 1\n\nРядок 2\r\n"),
        (almost199, almost199 + "\n")
    ])
    func newlinesInCompositionAreKeptAsIs(old: String, new: String) throws {
        let edit = SwitchNote.edit(from: old, to: new)
        #expect(try #require(fieldText(after: edit, new: new)) == new)
    }

    @Test func compositionOverTheLimitAtTheEndKeepsWhatFits() {
        #expect(SwitchNote.edit(from: almost199, to: almost199 + "аб") == .replace(text: almost199 + "а", cursor: 200))
    }

    @Test func longCompositionWithNewlinesKeepsItsFirstCharacters() {
        let old = String(full200.prefix(190))
        #expect(SwitchNote.edit(from: old, to: old + "\nКухня:\nвазон") == .replace(text: old + "\nКухня:\nва", cursor: 200))
    }

    // Повне поле: нове не входить — лишається старий текст, курсор там, де була правка.
    @Test(arguments: ["я", "\n", family])
    func compositionIntoFullFieldKeepsOldText(insertion: String) {
        let characters = Array(full200)
        let new = String(characters[..<50]) + insertion + String(characters[50...])
        #expect(SwitchNote.edit(from: full200, to: new) == .replace(text: full200, cursor: 50))
    }
}

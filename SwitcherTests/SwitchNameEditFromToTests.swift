import Foundation
import Testing
@testable import Switcher

// Правка, що потрапила в поле «Назва» в обхід делегата: складання символів (marked text — IME,
// диктування) або будь-яка інша зміна, яку делегат не бачив, — `SwitchName.edit(from:to:)`.
//
// `from` — останній прийнятий текст, `to` — те, що зараз у полі. Відповідь:
// - `.accept` — лишити в полі `to`;
// - `.replace(text:cursor:)` — поставити в поле `text`, курсор на `cursor` (зсув UTF-16).
// `.reject` і `.finish` тут не бувають: якщо не влазить нічого — `.replace` зі старим текстом
// і курсором там, де була правка.
//
// Правила ті самі, що в `edit(_:range:replacement:allowsNewlineFinish:)` з `allowsNewlineFinish: false`:
// результат не довший за `max(SwitchName.maxLength, from.count)` символів (`Character`);
// обрізається саме вставлене (лишаються його перші символи), решта тексту ціла;
// емодзі не розрізаються; переноси рядка у вставленому стають пробілами (кожна послідовність — одним).
// Правило «все або нічого» для виправлень одного слова тут НЕ діє: змінений шматок знайдено як різницю
// двох текстів, і його форма (слово поверх слова тощо) нічого не каже про те, що зробила людина, —
// тож вставлене завжди обрізається (див. `compositionOverSelectionInFullFieldReplacesOnlyAsMuchAsFits`,
// `longerReplacementInLegacyLongNameDoesNotGrowIt`).

/// Повне поле: рівно 30 символів (усі в BMP, тож UTF-16 — теж 30).
private let full30 = "Перевірила, чи вимкнена праска"
/// На один символ менше за межу.
private let almost29 = "Перевірила, чи вимкнена праск"
/// Назва, створена до появи межі: 51 символ. Перші 30 символів — `full30`.
private let legacy51 = "Перевірила, чи вимкнена праска перед виходом з дому"
/// Прапор: 1 символ, 4 одиниці UTF-16.
private let flag = "🇺🇦"
/// Сім'я з ZWJ: 1 символ, 8 одиниць UTF-16.
private let family = "👨‍👩‍👧"
/// Великий палець без відтінку: 1 символ, 2 одиниці UTF-16.
private let thumbsUp = "👍"
/// Великий палець з відтінком шкіри: 1 символ, 4 одиниці UTF-16.
private let thumbsUpTone = "👍🏽"
/// 29 символів з прапором на початку; UTF-16 — 4 + 1 + 27 = 32.
private let flagged29 = "🇺🇦 Перевірила, чи вимкнена пра"
/// 30 символів з прапором на початку; UTF-16 — 33.
private let flagged30 = "🇺🇦 Перевірила, чи вимкнена прас"

private func utf16Length(_ text: String) -> Int { (text as NSString).length }

/// `text` зі вставкою `insertion` перед символом (`Character`) з індексом `index`.
private func inserting(_ insertion: String, into text: String, at index: Int) -> String {
    let characters = Array(text)
    return String(characters[..<index]) + insertion + String(characters[index...])
}

/// `text`, у якому символ з індексом `index` замінено на `replacement`.
private func replacing(at index: Int, in text: String, with replacement: String) -> String {
    let characters = Array(text)
    return String(characters[..<index]) + replacement + String(characters[(index + 1)...])
}

/// Що опиниться в полі після відповіді; `nil` — відповідь, якої тут бути не може (`.reject`, `.finish`).
private func fieldText(after edit: SwitchNameEdit, new: String) -> String? {
    switch edit {
    case .accept: new
    case .replace(let text, _): text
    case .reject, .finish: nil
    }
}

/// Чи можна отримати `small` з `large`, викинувши частину скалярів Unicode (порядок той самий).
private func isSubsequence(_ small: String, of large: String) -> Bool {
    var iterator = large.unicodeScalars.makeIterator()
    outer: for scalar in small.unicodeScalars {
        while let next = iterator.next() {
            if next == scalar { continue outer }
        }
        return false
    }
    return true
}

/// Чи стоїть зсув UTF-16 на межі символу (не всередині емодзі).
private func isCharacterBoundary(_ offset: Int, in text: String) -> Bool {
    let source = text as NSString
    guard (0...source.length).contains(offset) else { return false }
    guard offset < source.length else { return true }
    return source.rangeOfComposedCharacterSequence(at: offset).location == offset
}

@MainActor
struct SwitchNameEditFromToTests {
    @Test func fixturesHaveExpectedLengths() {
        #expect(SwitchName.maxLength == 30)
        #expect(full30.count == 30 && utf16Length(full30) == 30)
        #expect(almost29.count == 29 && utf16Length(almost29) == 29)
        #expect(legacy51.count == 51 && legacy51.hasPrefix(full30))
        #expect(flag.count == 1 && utf16Length(flag) == 4)
        #expect(family.count == 1 && utf16Length(family) == 8)
        #expect(thumbsUp.count == 1 && utf16Length(thumbsUp) == 2)
        #expect(thumbsUpTone.count == 1 && utf16Length(thumbsUpTone) == 4)
        #expect(flagged29.count == 29 && utf16Length(flagged29) == 32)
        #expect(flagged30.count == 30 && utf16Length(flagged30) == 33)
    }

    // MARK: - Текст, що вкладається в межу, лишається як є

    @Test(arguments: [
        ("", "П"),
        ("", "Полила квіти"),
        ("Полила", "Полила квіти"),
        ("квіти", "Полила квіти"),
        (almost29, full30), // межа: 29 → 30
        ("", full30), // одразу 30
        (full30, almost29), // видалення в повному полі
        (full30, "Газ"), // заміна всього коротшим
        (flagged29, flagged30)
    ] as [(String, String)])
    func compositionThatFitsIsAccepted(old: String, new: String) {
        #expect(SwitchName.edit(from: old, to: new) == .accept)
    }

    @Test(arguments: ["", "Полила", full30, legacy51, flagged30, family, String(repeating: family, count: 30)])
    func unchangedTextIsAccepted(text: String) {
        #expect(SwitchName.edit(from: text, to: text) == .accept)
    }

    // MARK: - Складання дало більше, ніж влазить: обрізається вставлене, решта тексту ціла

    // 29 + «аю» → лишається лише «а»; курсор після вставленого.
    @Test func compositionOneOverTheLimitAtTheEndKeepsWhatFits() {
        #expect(SwitchName.edit(from: almost29, to: almost29 + "аю") == .replace(text: full30, cursor: 30))
    }

    @Test func longCompositionAtTheEndKeepsItsFirstCharacters() {
        let old = "Полила квіти" // 12
        let edit = SwitchName.edit(from: old, to: old + " у вітальні, на кухні й на балконі")
        let expected = "Полила квіти у вітальні, на ку" // 18 перших символів вставленого
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 30))
    }

    // У середині: обрізається вставлене, а не хвіст наявного тексту («квіти» лишається).
    @Test func longCompositionInTheMiddleKeepsTheTailOfExistingText() {
        let edit = SwitchName.edit(from: "Полила квіти", to: "Полила у вітальні, на кухні й на балконі квіти")
        let expected = "Полила у вітальні, на кухквіти"
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 25))
    }

    @Test func longCompositionAtTheStartKeepsExistingText() {
        let edit = SwitchName.edit(from: "квіти", to: "Полила у вітальні, на кухні й на балконі квіти")
        let expected = "Полила у вітальні, на кухквіти"
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 25))
    }

    // Курсор — у UTF-16: перед вставленим стоїть прапор (1 символ, 4 одиниці),
    // тож курсор після 2 + 23 символів — це 28, а не 25.
    @Test func cursorAfterTruncatedCompositionIsMeasuredInUTF16() {
        let old = flag + " квіти" // 7 символів
        let edit = SwitchName.edit(from: old, to: flag + " Полила у вітальні, на кухні й на балконі квіти")
        let expected = flag + " Полила у вітальні, на кквіти"
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 4 + 1 + 23))
    }

    @Test func cursorAtTheEndAfterEmojiIsMeasuredInUTF16() {
        #expect(SwitchName.edit(from: flagged29, to: flagged29 + "ой") == .replace(text: flagged29 + "о", cursor: 33))
    }

    // Складання замінило виділене довшим текстом у повному полі: замість 2 виділених — перші 2 символи.
    @Test func compositionOverSelectionInFullFieldReplacesOnlyAsMuchAsFits() {
        let edit = SwitchName.edit(from: full30, to: "Перевірила, абвгд вимкнена праска")
        #expect(edit == .replace(text: "Перевірила, аб вимкнена праска", cursor: 14))
    }

    // MARK: - Повне поле: складений символ не входить, лишається старий текст, курсор на місці правки

    // Індекс — у символах; курсор — у UTF-16 (у `full30` вони збігаються).
    @Test(arguments: [0, 10, 30])
    func compositionIntoFullFieldKeepsOldTextWithCursorAtTheEdit(index: Int) {
        let edit = SwitchName.edit(from: full30, to: inserting("я", into: full30, at: index))
        #expect(edit == .replace(text: full30, cursor: index))
    }

    @Test(arguments: [flag, family, thumbsUpTone, "вдома"])
    func emojiOrWordIntoFullFieldKeepsOldText(insertion: String) {
        #expect(SwitchName.edit(from: full30, to: full30 + insertion) == .replace(text: full30, cursor: 30))
    }

    // Повне поле з прапором на початку: курсор на місці правки — у UTF-16.
    @Test(arguments: [(2, 5), (30, 33)] as [(Int, Int)])
    func compositionIntoFullFieldWithEmojiPutsCursorAtUTF16Location(index: Int, cursor: Int) {
        let edit = SwitchName.edit(from: flagged30, to: inserting("я", into: flagged30, at: index))
        #expect(edit == .replace(text: flagged30, cursor: cursor))
    }

    // MARK: - Стара довга назва (понад 30): не обрізається, якщо нове не довше; не росте

    @Test(arguments: [
        String(legacy51.dropLast()), // backspace
        "Перевірила, чи вимкнена праска  виходом з дому", // видалено «перед»
        "Перевірила, чи вимкнена праска до виходом з дому", // «перед» → «до»
        "Перевірила, чи вимкнена праска після виходом з дому", // «перед» → «після», та сама довжина
        "Газ горить" // заміна всього коротшим
    ])
    func legacyLongNameEditThatDoesNotGrowIsAccepted(new: String) {
        #expect(SwitchName.edit(from: legacy51, to: new) == .accept)
    }

    @Test(arguments: [0, 30, 51])
    func compositionIntoLegacyLongNameKeepsOldText(index: Int) {
        let edit = SwitchName.edit(from: legacy51, to: inserting("я", into: legacy51, at: index))
        #expect(edit == .replace(text: legacy51, cursor: index))
    }

    // «перед» (5) → «напередодні» (11): лишаються перші 5 символів вставленого, назва не росте.
    @Test func longerReplacementInLegacyLongNameDoesNotGrowIt() {
        let edit = SwitchName.edit(from: legacy51, to: "Перевірила, чи вимкнена праска напередодні виходом з дому")
        let expected = "Перевірила, чи вимкнена праска напер виходом з дому"
        #expect(expected.count == 51)
        #expect(edit == .replace(text: expected, cursor: 36))
    }

    // MARK: - Емодзі й складені символи не розрізаються

    // На межі 30: з двох емодзі влазить лише перше — ціле, курсор після нього (у UTF-16).
    @Test(arguments: [(family, 8), (flag, 4), (thumbsUpTone, 4)] as [(String, Int)])
    func emojiCompositionAtTheLimitKeepsWholeCharacters(emoji: String, utf16: Int) {
        let edit = SwitchName.edit(from: almost29, to: almost29 + emoji + emoji)
        #expect(edit == .replace(text: almost29 + emoji, cursor: 29 + utf16))
    }

    // Модифікатор, ZWJ чи другий регіональний індикатор дописано до останнього символу повного поля:
    // символів так і лишається 30 — приймається як є (різниця всередині символу не ламає підрахунок).
    @Test(arguments: [
        (thumbsUp, thumbsUpTone),
        ("👨", family),
        ("🇺", flag),
        ("e", "e\u{0301}")
    ] as [(String, String)])
    func growingTheLastCharacterOfFullFieldIsAccepted(before: String, after: String) {
        #expect((almost29 + before).count == 30 && (almost29 + after).count == 30)
        #expect(SwitchName.edit(from: almost29 + before, to: almost29 + after) == .accept)
    }

    @Test func addingSkinToneToFirstCharacterOfFullFieldIsAccepted() {
        #expect(SwitchName.edit(from: thumbsUp + almost29, to: thumbsUpTone + almost29) == .accept)
    }

    @Test func removingSkinToneIsAccepted() {
        #expect(SwitchName.edit(from: thumbsUpTone, to: thumbsUp) == .accept)
        #expect(SwitchName.edit(from: almost29 + thumbsUpTone, to: almost29 + thumbsUp) == .accept)
    }

    // Відтінок шкіри дописано до 👍 на межі разом з ще одним символом: 👍🏽 лишається цілим,
    // зайвий символ відкидається, курсор після 👍🏽 (29 + 4).
    @Test func skinTonePlusExtraCharacterAtTheLimitKeepsWholeEmoji() {
        let edit = SwitchName.edit(from: almost29 + thumbsUp, to: almost29 + thumbsUpTone + "я")
        #expect(edit == .replace(text: almost29 + thumbsUpTone, cursor: 33))
    }

    @Test func skinTonePlusExtraCharacterAtTheStartKeepsTheRestOfText() {
        let edit = SwitchName.edit(from: thumbsUp + almost29, to: thumbsUpTone + "я" + almost29)
        #expect(edit == .replace(text: thumbsUpTone + almost29, cursor: 4))
    }

    @Test func familyPlusExtraCharacterAtTheLimitKeepsWholeEmoji() {
        let edit = SwitchName.edit(from: almost29 + "👨", to: almost29 + family + "я")
        #expect(edit == .replace(text: almost29 + family, cursor: 29 + 8))
    }

    // Той самий символ у іншій нормалізації Unicode («é» одним скаляром і «e» + наголос) —
    // курсор має відповідати тексту, який повертається, а не тексту в полі.
    @Test func cursorMatchesTheReturnedTextWhenNormalizationDiffers() throws {
        let old = "caf\u{00E9}" + String(repeating: "x", count: 25) // 29 символів, UTF-16 29
        let new = "cafe\u{0301}" + String(repeating: "x", count: 25) + "яю" // 31 символ, UTF-16 32
        let edit = SwitchName.edit(from: old, to: new)
        guard case .replace(let text, let cursor) = edit else {
            Issue.record("очікувався .replace, а не \(edit)")
            return
        }
        #expect(text == old + "я")
        #expect(text.count == 30)
        #expect(cursor == utf16Length(text))
    }

    // MARK: - Неоднозначна різниця (повторювані символи)

    @Test func repeatedCharacterThatFitsIsAccepted() {
        #expect(SwitchName.edit(from: "ааа", to: "аааа") == .accept)
    }

    // Де саме вставлено «а» в рядок з самих «а» — невідомо; але текст лишається 30 «а»,
    // а курсор — у межах тексту.
    @Test(arguments: [(30, 31), (29, 32), (1, 40)] as [(Int, Int)])
    func repeatedCharactersOverTheLimitKeepThirty(oldCount: Int, newCount: Int) throws {
        let old = String(repeating: "а", count: oldCount)
        let edit = SwitchName.edit(from: old, to: String(repeating: "а", count: newCount))
        guard case .replace(let text, let cursor) = edit else {
            Issue.record("очікувався .replace, а не \(edit)")
            return
        }
        #expect(text == String(repeating: "а", count: 30))
        #expect((0...30).contains(cursor))
    }

    // «ма» вставлено двічі десь у «мамама…»: у результаті рівно 30 символів, увесь старий текст на місці
    // (у тому ж порядку), а все, що в полі, — з нового тексту.
    @Test(arguments: [
        ("Ой" + String(repeating: "ма", count: 13) + "!", "Ой" + String(repeating: "ма", count: 15) + "!"),
        ("Полила квіти", "Полила квіти квіти квіти квіти квіти"),
        ("Газ горить", "Газ гогогогогогогогогогогогогогорить")
    ] as [(String, String)])
    func ambiguousCompositionKeepsExistingText(old: String, new: String) throws {
        let edit = SwitchName.edit(from: old, to: new)
        let text = try #require(fieldText(after: edit, new: new))
        #expect(text.count == SwitchName.maxLength)
        #expect(isSubsequence(old, of: text), "загубився наявний текст: \(text)")
        #expect(isSubsequence(text, of: new), "у полі текст, якого не було: \(text)")
        if case .replace(let newText, let cursor) = edit {
            #expect(isCharacterBoundary(cursor, in: newText))
        }
    }

    // MARK: - Переноси рядка: пробіл (кожна послідовність — одним); «Готово» не буває

    @Test(arguments: [
        ("", "Полила\nквіти", "Полила квіти", 12),
        ("", "Полила\r\nквіти", "Полила квіти", 12),
        ("", "Полила\n\n\nквіти", "Полила квіти", 12),
        ("Полила", "Полила\nквіти", "Полила квіти", 12),
        ("Полила", "Полила\n", "Полила ", 7),
        ("квіти", "Полила\nквіти", "Полила квіти", 7),
        ("Газ", "Газ\n\nгорить\n", "Газ горить ", 11),
        (flag, flag + "\nвдома", flag + " вдома", 10)
    ] as [(String, String, String, Int)])
    func newlinesInCompositionBecomeSpaces(old: String, new: String, expected: String, cursor: Int) {
        #expect(SwitchName.edit(from: old, to: new) == .replace(text: expected, cursor: cursor))
    }

    @Test func newlinesInCompositionRespectTheLimit() {
        let old = String(almost29.dropLast(4)) // 25
        // «аб\n\nвгд» → «аб вгд» (6) → влазить 5: «аб вг»
        #expect(SwitchName.edit(from: old, to: old + "аб\n\nвгд") == .replace(text: old + "аб вг", cursor: 30))
    }

    @Test(arguments: [(30, "\n"), (10, "\nвдома\n"), (0, "\r\n")] as [(Int, String)])
    func newlinesIntoFullFieldKeepOldText(index: Int, insertion: String) {
        let edit = SwitchName.edit(from: full30, to: inserting(insertion, into: full30, at: index))
        #expect(edit == .replace(text: full30, cursor: index))
    }

    // MARK: - Заміна всього тексту

    @Test func replacingEverythingWithLongTextKeepsItsFirstThirtyCharacters() {
        #expect(SwitchName.edit(from: "Газ", to: legacy51) == .replace(text: full30, cursor: 30))
        let long = "Двері зачинені на два оберти й на ланцюжок"
        let expected = "Двері зачинені на два оберти й"
        #expect(long.count > 30 && expected.count == 30 && long.hasPrefix(expected))
        #expect(SwitchName.edit(from: full30, to: long) == .replace(text: expected, cursor: 30))
        #expect(SwitchName.edit(from: "", to: long) == .replace(text: expected, cursor: 30))
    }

    // MARK: - Інваріанти для будь-якої вставки чи заміни символу

    // Для кожної позиції: відповідь лише `.accept` або `.replace`; результат не довший за
    // max(30, стара довжина), без переносів; якщо новий текст влазить і без переносів — `.accept`;
    // курсор у межах тексту й на межі символу; наявний текст не губиться.
    @Test(arguments: [
        "", "Полила", almost29, full30, legacy51, flagged29, flagged30,
        String(repeating: "а", count: 30), String(repeating: family, count: 30), thumbsUp + almost29
    ])
    func everyCompositionStaysWithinTheLimit(old: String) throws {
        let insertions = [
            "я", "ой", family + flag + thumbsUpTone, "\u{1F3FD}", "\u{0301}", "\n", "а\r\nб",
            String(repeating: "ж", count: 40)
        ]
        let limit = max(SwitchName.maxLength, old.count)
        for insertion in insertions {
            for index in 0...old.count {
                var news = [(new: inserting(insertion, into: old, at: index), isInsertion: true)]
                if index < old.count {
                    news.append((replacing(at: index, in: old, with: insertion), false))
                }
                for (new, isInsertion) in news {
                    let edit = SwitchName.edit(from: old, to: new)
                    let context = "«\(old)» → «\(new)»: \(edit)"
                    let text = try #require(fieldText(after: edit, new: new), "\(context)")
                    #expect(text.count <= limit, "\(context)")
                    let hasNewlines = text.contains(where: \.isNewline)
                    #expect(!hasNewlines, "\(context)")
                    if new.count <= limit, !new.contains(where: \.isNewline) {
                        #expect(edit == .accept, "\(context)")
                    }
                    if case .replace(let newText, let cursor) = edit {
                        #expect(isCharacterBoundary(cursor, in: newText), "\(context)")
                    }
                    if isInsertion, !insertion.contains(where: \.isNewline) {
                        #expect(isSubsequence(old, of: text), "загубився наявний текст: \(context)")
                        #expect(isSubsequence(text, of: new), "текст, якого не було: \(context)")
                    }
                }
            }
        }
    }
}

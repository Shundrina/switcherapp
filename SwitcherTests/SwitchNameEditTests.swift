import Foundation
import Testing
@testable import Switcher

// Рішення делегата полів «Назва» (`UITextField` на екрані додавання, `UITextView` на екрані
// перемикача): що робити з правкою ДО того, як вона потрапить у поле —
// `SwitchName.edit(_:range:replacement:allowsNewlineFinish:)`.
//
// Делегат отримує поточний текст, діапазон `NSRange` у одиницях UTF-16 і рядок заміни.
// Відповідь — `SwitchNameEdit`:
// - `.accept` — делегат повертає `true`, UIKit сам застосовує правку;
// - `.replace(text:cursor:)` — делегат повертає `false`, сам ставить `text` і курсор
//   на `cursor` (зсув у UTF-16 від початку тексту — так рахує `UITextInput`);
// - `.reject` — делегат повертає `false`, текст не змінюється;
// - `.finish` — «Готово» в полі редагування: текст не змінюється, редагування завершується.
//
// Межа: результат правки не довший за `max(SwitchName.maxLength, поточна довжина)` символів
// (`Character`). Тобто правка, що не збільшує текст, приймається завжди — навіть у старій
// назві понад 30 символів, — а вставка понад межу обрізається до тієї кількості перших
// символів вставки, яка влазить.
//
// Виняток — правки, схожі на виправлення чи підказку ОДНОГО слова (незалежно від спільних символів):
// (а) непорожній діапазон без пробільних символів, а заміна без кінцевого пробілу — одне слово
//     без пробільних символів (автовиправлення «квти» → «квіти», «кух» → «Кухні », підказка-доповнення
//     «кух» → «кухні », слово поверх слова «чи» → «абвгд»);
// (б) порожній діапазон, а заміна — одне слово з кінцевим пробілом (підказка наступного слова «кухні »).
// Такі правки застосовуються всі або ніяк (`.reject`); дозволено лише відкинути кінцевий пробіл
// заміни, якщо без нього влазить. Усе інше (фраза поверх «виділити все», одне довге слово без
// кінцевого пробілу в порожній діапазон, вставка з пробілами всередині) обрізається.

/// Повне поле: рівно 30 символів (усі в BMP, тож UTF-16 — теж 30).
private let full30 = "Перевірила, чи вимкнена праска"
/// На один символ менше за межу.
private let almost29 = "Перевірила, чи вимкнена праск"
/// Назва, створена до появи межі: 51 символ.
private let legacy51 = "Перевірила, чи вимкнена праска перед виходом з дому"
/// Прапор: 1 символ, 4 одиниці UTF-16 (два регіональні індикатори).
private let flag = "🇺🇦"
/// Сім'я з ZWJ: 1 символ, 8 одиниць UTF-16.
private let family = "👨‍👩‍👧"
/// Великий палець з відтінком шкіри: 1 символ, 4 одиниці UTF-16.
private let thumbsUp = "👍🏽"
/// 29 символів з прапором на початку: «🇺🇦 » + 27 літер; UTF-16 — 4 + 1 + 27 = 32.
private let flagged29 = "🇺🇦 Перевірила, чи вимкнена пра"

private func utf16Length(_ text: String) -> Int { (text as NSString).length }

/// Діапазон у кінці тексту (курсор у кінці, нічого не виділено).
private func endOf(_ text: String) -> NSRange { NSRange(location: utf16Length(text), length: 0) }

/// Що опиниться в полі після відповіді делегата; `nil` — редагування завершено (`.finish`).
private func fieldText(after edit: SwitchNameEdit, text: String, range: NSRange, replacement: String) -> String? {
    switch edit {
    case .accept: (text as NSString).replacingCharacters(in: range, with: replacement)
    case .replace(let newText, _): newText
    case .reject: text
    case .finish: nil
    }
}

@MainActor
struct SwitchNameEditTests {
    @Test func fixturesHaveExpectedLengths() {
        #expect(SwitchName.maxLength == 30)
        #expect(full30.count == 30 && utf16Length(full30) == 30)
        #expect(almost29.count == 29 && utf16Length(almost29) == 29)
        #expect(legacy51.count == 51)
        #expect(flag.count == 1 && utf16Length(flag) == 4)
        #expect(family.count == 1 && utf16Length(family) == 8)
        #expect(thumbsUp.count == 1 && utf16Length(thumbsUp) == 4)
        #expect(flagged29.count == 29 && utf16Length(flagged29) == 32)
    }

    // MARK: - Правка, після якої текст не довший за 30, приймається як є

    @Test(arguments: [false, true])
    func typingIntoEmptyFieldIsAccepted(allowsNewlineFinish: Bool) {
        #expect(SwitchName.edit("", range: endOf(""), replacement: "П", allowsNewlineFinish: allowsNewlineFinish) == .accept)
    }

    // Межа: 29 → 30 приймається (зсув межі на −1 цей тест ламає).
    @Test(arguments: [false, true])
    func typingTheThirtiethCharacterIsAccepted(allowsNewlineFinish: Bool) {
        #expect(SwitchName.edit(almost29, range: endOf(almost29), replacement: "а", allowsNewlineFinish: allowsNewlineFinish) == .accept)
    }

    // Вставка, що рівно доводить до 30, — теж як є.
    @Test func pasteThatExactlyFillsTheFieldIsAccepted() {
        let text = "Полила квіти" // 12
        let paste = " на балконі вдома!" // 18
        #expect(text.count + paste.count == 30)
        #expect(SwitchName.edit(text, range: endOf(text), replacement: paste, allowsNewlineFinish: false) == .accept)
    }

    // Вставка в середину, якщо все влазить.
    @Test func insertionInTheMiddleThatFitsIsAccepted() {
        let text = "Полила квіти"
        #expect(SwitchName.edit(text, range: NSRange(location: 7, length: 0), replacement: "усі ", allowsNewlineFinish: true) == .accept)
    }

    // Порожня правка (нічого не виділено, нічого не вставлено) нічого не ламає.
    @Test func emptyEditIsAccepted() {
        #expect(SwitchName.edit(full30, range: NSRange(location: 5, length: 0), replacement: "", allowsNewlineFinish: false) == .accept)
    }

    // Пробіл у кінці не відкидається й не обрізається, інакше не надрукувати наступне слово.
    @Test(arguments: [false, true])
    func typingSpaceAfterWordIsAccepted(allowsNewlineFinish: Bool) {
        #expect(SwitchName.edit("Полила", range: endOf("Полила"), replacement: " ", allowsNewlineFinish: allowsNewlineFinish) == .accept)
    }

    // Виділила все в повному полі й надрукувала коротше — як є.
    @Test func replacingEverythingInFullFieldWithShorterTextIsAccepted() {
        #expect(SwitchName.edit(full30, range: NSRange(location: 0, length: 30), replacement: "Газ горить", allowsNewlineFinish: true) == .accept)
    }

    // MARK: - Повне поле: нові символи не вводяться

    // Межа: 30 → 31 відкидається (зсув межі на +1 цей тест ламає).
    @Test(arguments: [false, true], [0, 10, 30])
    func typingIntoFullFieldIsRejected(allowsNewlineFinish: Bool, cursor: Int) {
        let edit = SwitchName.edit(full30, range: NSRange(location: cursor, length: 0), replacement: "я", allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .reject)
    }

    // Пробіл — теж новий символ.
    @Test(arguments: [false, true])
    func spaceIntoFullFieldIsRejected(allowsNewlineFinish: Bool) {
        #expect(SwitchName.edit(full30, range: endOf(full30), replacement: " ", allowsNewlineFinish: allowsNewlineFinish) == .reject)
    }

    @Test(arguments: [false, true])
    func pasteIntoFullFieldIsRejected(allowsNewlineFinish: Bool) {
        let edit = SwitchName.edit(full30, range: NSRange(location: 10, length: 0), replacement: "вдома", allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .reject)
    }

    // Емодзі — один символ: у повне поле не входить.
    @Test(arguments: [flag, family, thumbsUp])
    func emojiIntoFullFieldIsRejected(emoji: String) {
        #expect(SwitchName.edit(full30, range: endOf(full30), replacement: emoji, allowsNewlineFinish: false) == .reject)
    }

    // Комбінований знак наголосу зливається з попередньою літерою: символів так і лишається 30,
    // тож правка приймається (рахуємо `Character`, а не скаляри чи UTF-16).
    @Test func combiningMarkIntoFullFieldKeepsCountAndIsAccepted() {
        let text = String(full30.dropLast()) + "e" // 30 символів, у кінці латинська «e»
        #expect(text.count == 30)
        let edit = SwitchName.edit(text, range: endOf(text), replacement: "\u{0301}", allowsNewlineFinish: false)
        #expect(edit == .accept)
    }

    // Те саме для «и» + бревіс (→ «й») і «палець угору» + тон шкіри: знак дописано в кінець
    // повного поля або останній символ замінено складеним — символів так і лишається 30.
    @Test(arguments: [("\u{438}", "\u{306}"), ("\u{1F44D}", "\u{1F3FD}")] as [(String, String)])
    func markThatMergesWithLastCharacterOfFullFieldIsAccepted(last: String, mark: String) throws {
        let text = String(repeating: "а", count: 29) + last
        try #require(text.count == 30 && (text + mark).count == 30)
        #expect(SwitchName.edit(text, range: endOf(text), replacement: mark, allowsNewlineFinish: false) == .accept)
        let lastRange = NSRange(location: 29, length: utf16Length(last))
        #expect(SwitchName.edit(text, range: lastRange, replacement: last + mark, allowsNewlineFinish: true) == .accept)
    }

    // Складений символ тридцятим (родина з чотирьох через ZWJ, прапор, «и» + бревіс) лишається цілим,
    // коли в повне поле пробують вписати літеру всередину.
    @Test(arguments: [
        "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}",
        "\u{1F1FA}\u{1F1E6}",
        "\u{438}\u{306}"
    ])
    func typingIntoFullFieldWithClusterAtTheLimitIsRejected(cluster: String) throws {
        let text = String(repeating: "а", count: 29) + cluster
        try #require(text.count == 30)
        #expect(SwitchName.edit(text, range: NSRange(location: 10, length: 0), replacement: "я", allowsNewlineFinish: false) == .reject)
    }

    // MARK: - Вставка, що не влазить: лише перші символи вставки, решта тексту ціла

    // 29 + «яю» → вставляється лише «я»; курсор після вставленого.
    @Test func pasteOneOverTheLimitInsertsOnlyWhatFits() {
        let edit = SwitchName.edit(almost29, range: endOf(almost29), replacement: "аю", allowsNewlineFinish: false)
        #expect(edit == .replace(text: almost29 + "а", cursor: 30))
    }

    @Test func longPasteAtTheEndInsertsItsFirstCharacters() {
        let text = "Полила квіти" // 12
        let edit = SwitchName.edit(text, range: endOf(text), replacement: " у вітальні, на кухні й на балконі", allowsNewlineFinish: true)
        // 18 перших символів вставки
        let expected = "Полила квіти у вітальні, на ку"
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 30))
    }

    // Вставка в середину: обрізається вставка, а не хвіст наявного тексту.
    @Test func longPasteInTheMiddleKeepsTheTailOfExistingText() {
        let text = "Полила квіти" // курсор після «Полила » (UTF-16: 7)
        let edit = SwitchName.edit(text, range: NSRange(location: 7, length: 0), replacement: "у вітальні, на кухні й на балконі ", allowsNewlineFinish: false)
        let expected = "Полила у вітальні, на кухквіти"
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 25))
    }

    // Довга вставка в порожнє поле — перші 30 символів.
    @Test func longPasteIntoEmptyFieldKeepsFirstThirtyCharacters() {
        #expect(SwitchName.edit("", range: endOf(""), replacement: legacy51, allowsNewlineFinish: true) == .replace(text: full30, cursor: 30))
    }

    @Test func longPasteAtTheStartKeepsExistingText() {
        let text = "квіти" // 5
        let edit = SwitchName.edit(text, range: NSRange(location: 0, length: 0), replacement: "Полила у вітальні, на кухні й на балконі ", allowsNewlineFinish: false)
        let expected = "Полила у вітальні, на кухквіти"
        #expect(expected.count == 30)
        #expect(edit == .replace(text: expected, cursor: 25))
    }

    // Повне поле, виділено 2 символи, вставка фрази з 6 → замість виділеного стають перші 2 символи вставки.
    @Test func phrasePasteOverSelectionInFullFieldReplacesOnlyAsMuchAsFits() {
        // «Перевірила, чи вимкнена праска»: виділено «чи» (UTF-16: 12..<14)
        let edit = SwitchName.edit(full30, range: NSRange(location: 12, length: 2), replacement: "аб вгд", allowsNewlineFinish: true)
        #expect(edit == .replace(text: "Перевірила, аб вимкнена праска", cursor: 14))
    }

    // Слово поверх слова (виділено «чи», вставка «абвгд») схоже на виправлення: усе або нічого.
    // У повне поле не влазить — текст не змінюється (а не обрізане «аб»).
    @Test(arguments: ["абвгд", "абвгд "])
    func wordPasteOverSelectedWordThatDoesNotFitIsRejected(replacement: String) {
        let edit = SwitchName.edit(full30, range: NSRange(location: 12, length: 2), replacement: replacement, allowsNewlineFinish: true)
        #expect(edit == .reject)
    }

    // «Виділити все» + довга фраза — звичайна вставка: перші 30 символів, незалежно від того,
    // чи збігається перша або остання літера фрази з виділеним текстом.
    @Test(arguments: [
        ("Перевірила, чи вимкнена праска перед виходом з дому", "Перевірила, чи вимкнена праска"), // спільна перша «П»
        ("Газ на кухні вимкнула зранку, потім полила квіти", "Газ на кухні вимкнула зранку, "), // спільна остання «и»
        ("Двері зачинені на два оберти й на ланцюжок", "Двері зачинені на два оберти й") // нічого спільного
    ] as [(String, String)], [false, true])
    func phrasePasteOverWholeTextKeepsItsFirstThirtyCharacters(sample: (String, String), allowsNewlineFinish: Bool) throws {
        let (paste, expected) = sample
        let text = "Полила квіти"
        try #require(expected.count == 30 && utf16Length(expected) == 30)
        let edit = SwitchName.edit(text, range: NSRange(location: 0, length: utf16Length(text)), replacement: paste, allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .replace(text: expected, cursor: 30))
    }

    // Одне довге слово без кінцевого пробілу в порожній діапазон — звичайна вставка, обрізається.
    @Test func longWordPasteWithoutTrailingSpaceIsTruncated() {
        let edit = SwitchName.edit("Полила квіти на балконі й ", range: NSRange(location: 26, length: 0), replacement: "кухнях", allowsNewlineFinish: false)
        #expect(edit == .replace(text: "Полила квіти на балконі й кухн", cursor: 30))
    }

    // Заміна виділеного тією самою кількістю символів у повному полі — як є.
    @Test func typingOverSelectionInFullFieldIsAccepted() {
        #expect(SwitchName.edit(full30, range: NSRange(location: 12, length: 2), replacement: "аб", allowsNewlineFinish: false) == .accept)
        #expect(SwitchName.edit(full30, range: NSRange(location: 12, length: 1), replacement: "я", allowsNewlineFinish: false) == .accept)
    }

    // Слово поверх слова, що починається так само, як виділене («чи» → «чим»):
    // у повному полі нового символу немає куди вставити — текст не змінюється.
    @Test func pasteOverSelectionWithCommonStartInFullFieldKeepsText() throws {
        let range = NSRange(location: 12, length: 2) // «чи»
        let edit = SwitchName.edit(full30, range: range, replacement: "чим", allowsNewlineFinish: false)
        let result = try #require(fieldText(after: edit, text: full30, range: range, replacement: "чим"))
        #expect(result == full30)
    }

    // Те саме в майже повному полі: слово поверх слова — як виправлення, усе або нічого.
    // «чимало» замість «чи» не влазить цілим — текст не змінюється (а не «чим»).
    @Test func pasteOverSelectionWithCommonStartThatDoesNotFitIsRejected() {
        // «Перевірила, чи вимкнена праск»: виділено «чи» (UTF-16: 12..<14)
        let edit = SwitchName.edit(almost29, range: NSRange(location: 12, length: 2), replacement: "чимало", allowsNewlineFinish: false)
        #expect(edit == .reject)
    }

    // MARK: - Автовиправлення: UIKit замінює набране слово виправленим
    //
    // `range` — усе набране слово, `replacement` — виправлене. Спільний початок і кінець старого
    // й нового слова — не нові символи: «квти» → «квіти» додає лише «і». Виправлення одного слова
    // (правило (а) з шапки файлу) застосовується все або ніяк: не влазить — не застосовується зовсім,
    // а не обрізає слово («квіт», «прака») чи хвіст тексту.

    @Test(arguments: [
        ("Полила квти на балконі й кухні", NSRange(location: 7, length: 4), "квіти"), // усередині
        ("Полила квіти на балконі й кхні", NSRange(location: 26, length: 4), "кухні"), // у кінці
        ("Плила квіти на балконі й кухні", NSRange(location: 0, length: 5), "Полила"), // на початку
        ("🇺🇦 Полила квти на балконі й кух", NSRange(location: 12, length: 4), "квіти") // діапазон у UTF-16
    ] as [(String, NSRange, String)], [false, true])
    func autocorrectToLongerWordInFullFieldIsRejected(sample: (String, NSRange, String), allowsNewlineFinish: Bool) throws {
        let (text, range, replacement) = sample
        try #require(text.count == SwitchName.maxLength)
        let edit = SwitchName.edit(text, range: range, replacement: replacement, allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .reject)
    }

    // Майже повне поле (29): «прка» → «праска» додає «ас», а влазить лише одна літера —
    // виправлення не застосовується (а не «прака» з курсором посеред слова).
    @Test(arguments: [false, true])
    func autocorrectThatOnlyPartlyFitsIsRejected(allowsNewlineFinish: Bool) throws {
        let text = "Перевірила, чи вимкнена прка!"
        try #require(text.count == 29)
        let edit = SwitchName.edit(text, range: NSRange(location: 24, length: 4), replacement: "праска", allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .reject)
    }

    // Стара довга назва (50 символів): виправлення «виходм» → «виходом» зробило б її довшою — не застосовується.
    @Test func autocorrectToLongerWordInLegacyLongNameIsRejected() throws {
        let text = "Перевірила, чи вимкнена праска перед виходм з дому"
        try #require(text.count == 50)
        let edit = SwitchName.edit(text, range: NSRange(location: 37, length: 6), replacement: "виходом", allowsNewlineFinish: true)
        #expect(edit == .reject)
    }

    // Виправлення, що вкладається в межу, UIKit застосовує сам — зокрема 29 → 30.
    @Test(arguments: [
        ("Полила квти", NSRange(location: 7, length: 4), "квіти"),
        ("Полила квти на балконі й кхні", NSRange(location: 7, length: 4), "квіти"), // 29 → 30
        ("Полила квти на балконі й кхні", NSRange(location: 25, length: 4), "кухні") // 29 → 30, у кінці
    ] as [(String, NSRange, String)], [false, true])
    func autocorrectThatFitsIsAccepted(sample: (String, NSRange, String), allowsNewlineFinish: Bool) {
        let (text, range, replacement) = sample
        let edit = SwitchName.edit(text, range: range, replacement: replacement, allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .accept)
    }

    // Виправлення на таке саме чи коротше слово в повному полі й у старій довгій назві — як є.
    @Test(arguments: [
        ("Перевірила, чи вимкнена прсака", NSRange(location: 24, length: 6), "праска"), // та сама довжина
        ("Перевірила, чи вимкненна праск", NSRange(location: 15, length: 9), "вимкнена"), // коротше
        ("Перевірила, чи вимкнена прсака перед виходом з дому", NSRange(location: 24, length: 6), "праска") // 51
    ] as [(String, NSRange, String)])
    func autocorrectToSameOrShorterWordIsAccepted(sample: (String, NSRange, String)) throws {
        let (text, range, replacement) = sample
        try #require(text.count >= SwitchName.maxLength)
        #expect(SwitchName.edit(text, range: range, replacement: replacement, allowsNewlineFinish: true) == .accept)
    }

    // Той самий символ в іншій нормалізації Unicode («é» одним скаляром → «e» + наголос):
    // символів у повному полі не додається — текст лишається тим самим (з точністю до нормалізації),
    // а курсор, якщо його ставить делегат, — у межах тексту й на межі символу.
    @Test func autocorrectToCanonicallyEquivalentWordInFullFieldKeepsText() throws {
        let text = "Перевірила, чи вимкнена у caf\u{00E9}"
        try #require(text.count == 30 && utf16Length(text) == 30)
        let range = NSRange(location: 26, length: 4) // «café»
        let replacement = "cafe\u{0301}"
        let edit = SwitchName.edit(text, range: range, replacement: replacement, allowsNewlineFinish: false)
        let result = try #require(fieldText(after: edit, text: text, range: range, replacement: replacement))
        #expect(result == text) // `String ==` порівнює з урахуванням канонічної еквівалентності
        #expect(result.count == 30)
        if case .replace(let newText, let cursor) = edit {
            let source = newText as NSString
            #expect((0...source.length).contains(cursor))
            if cursor < source.length {
                #expect(source.rangeOfComposedCharacterSequence(at: cursor).location == cursor)
            }
        }
    }

    // MARK: - Підказка з панелі над клавіатурою: «кух» → «кухні »
    //
    // UIKit замінює недописане слово підказкою з пробілом у кінці (правило (а) з шапки файлу).
    // Як і автовиправлення — усе або нічого; єдиний виняток: кінцевий пробіл підказки можна
    // відкинути, якщо без нього слово влазить ціле.

    @Test func suggestionThatFitsIsAccepted() {
        let edit = SwitchName.edit("Полила кух", range: NSRange(location: 7, length: 3), replacement: "кухні ", allowsNewlineFinish: false)
        #expect(edit == .accept)
    }

    // 28 символів: «кухні » не влазить, «кухні» — так: слово ціле, без пробілу, курсор після «і».
    @Test(arguments: [
        ("Полила квіти на балконі, кух", NSRange(location: 25, length: 3), "Полила квіти на балконі, кухні", 30), // у кінці
        ("Полила кух на балконі, кухні", NSRange(location: 7, length: 3), "Полила кухні на балконі, кухні", 12) // усередині
    ] as [(String, NSRange, String, Int)])
    func suggestionThatFitsWithoutTrailingSpaceInsertsWholeWordWithoutSpace(sample: (String, NSRange, String, Int)) throws {
        let (text, range, expected, cursor) = sample
        try #require(text.count == 28 && expected.count == 30)
        let edit = SwitchName.edit(text, range: range, replacement: "кухні ", allowsNewlineFinish: false)
        #expect(edit == .replace(text: expected, cursor: cursor))
    }

    // 29 символів: навіть без пробілу «кухні» не влазить — підказка не застосовується (а не «кухн»).
    @Test func suggestionThatDoesNotFitEvenWithoutTrailingSpaceIsRejected() throws {
        let text = "Полила квіти на балконі й кух"
        try #require(text.count == 29)
        let edit = SwitchName.edit(text, range: NSRange(location: 26, length: 3), replacement: "кухні ", allowsNewlineFinish: false)
        #expect(edit == .reject)
    }

    // Повне поле: «кухн» → «кухні » нічого не додає — текст не змінюється.
    @Test func suggestionInFullFieldKeepsText() throws {
        let text = "Полила квіти на балконі й кухн"
        try #require(text.count == 30)
        let range = NSRange(location: 26, length: 4)
        let edit = SwitchName.edit(text, range: range, replacement: "кухні ", allowsNewlineFinish: false)
        let result = try #require(fieldText(after: edit, text: text, range: range, replacement: "кухні "))
        #expect(result == text)
    }

    // Автовиправлення зі зміною регістру («кух» → «Кухні »): спільних символів немає, але це те саме
    // виправлення одного слова — усе або нічого.
    @Test func capitalizingSuggestionThatFitsIsAccepted() {
        let edit = SwitchName.edit("Полила кух", range: NSRange(location: 7, length: 3), replacement: "Кухні ", allowsNewlineFinish: false)
        #expect(edit == .accept)
    }

    @Test func capitalizingSuggestionThatFitsWithoutTrailingSpaceInsertsWholeWordWithoutSpace() {
        let edit = SwitchName.edit("Полила квіти на балконі, кух", range: NSRange(location: 25, length: 3), replacement: "Кухні ", allowsNewlineFinish: false)
        #expect(edit == .replace(text: "Полила квіти на балконі, Кухні", cursor: 30))
    }

    // 29 символів: «Кухні» не влазить — не застосовується (а не «Кухн»).
    @Test func capitalizingSuggestionThatDoesNotFitIsRejected() {
        let edit = SwitchName.edit("Полила квіти на балконі й кух", range: NSRange(location: 26, length: 3), replacement: "Кухні ", allowsNewlineFinish: false)
        #expect(edit == .reject)
    }

    // MARK: - Підказка наступного слова: порожній діапазон, одне слово з кінцевим пробілом
    //
    // Правило (б) з шапки файлу: усе або нічого, кінцевий пробіл можна відкинути.

    @Test func nextWordSuggestionThatFitsIsAccepted() {
        let edit = SwitchName.edit("Полила квіти й ", range: NSRange(location: 15, length: 0), replacement: "кухні ", allowsNewlineFinish: false)
        #expect(edit == .accept)
    }

    // 25 символів: «кухні » не влазить, «кухні» — так: слово без пробілу, курсор після нього.
    @Test func nextWordSuggestionThatFitsWithoutTrailingSpaceInsertsWholeWordWithoutSpace() throws {
        let text = "Полила квіти в кімнаті й "
        try #require(text.count == 25)
        let edit = SwitchName.edit(text, range: NSRange(location: 25, length: 0), replacement: "кухні ", allowsNewlineFinish: false)
        #expect(edit == .replace(text: text + "кухні", cursor: 30))
    }

    // 26 символів: «кухні» не влазить і без пробілу — підказка не застосовується (а не «кухн»).
    @Test func nextWordSuggestionThatDoesNotFitIsRejected() throws {
        let text = "Полила квіти на балконі й "
        try #require(text.count == 26)
        let edit = SwitchName.edit(text, range: NSRange(location: 26, length: 0), replacement: "кухні ", allowsNewlineFinish: false)
        #expect(edit == .reject)
    }

    // MARK: - Емодзі й складені символи не розрізаються

    // На межі 30: з двох емодзі влазить лише перше — ціле, курсор після нього (у UTF-16).
    @Test(arguments: [(family, 8), (flag, 4), (thumbsUp, 4)])
    func emojiPasteAtTheLimitKeepsWholeCharacters(emoji: String, utf16: Int) {
        let edit = SwitchName.edit(almost29, range: endOf(almost29), replacement: emoji + emoji, allowsNewlineFinish: false)
        #expect(edit == .replace(text: almost29 + emoji, cursor: 29 + utf16))
    }

    // Межа 30 посеред вставки: «а» і ціла сім'я влазять, «б» — ні.
    @Test func mixedPasteAtTheLimitCountsCharactersNotUTF16() {
        let text = String(almost29.dropLast()) // 28
        let edit = SwitchName.edit(text, range: endOf(text), replacement: "а" + family + "б", allowsNewlineFinish: false)
        #expect(edit == .replace(text: text + "а" + family, cursor: 28 + 1 + 8))
    }

    // Емодзі як 30-й символ — приймається (рахуємо символи, а не одиниці UTF-16).
    @Test(arguments: [flag, family, thumbsUp])
    func emojiAsThirtiethCharacterIsAccepted(emoji: String) {
        #expect(SwitchName.edit(almost29, range: endOf(almost29), replacement: emoji, allowsNewlineFinish: true) == .accept)
    }

    // Діапазон у UTF-16: курсор у кінці тексту з прапором — це 32, а не 29.
    @Test func rangeIsMeasuredInUTF16() {
        #expect(SwitchName.edit(flagged29, range: NSRange(location: 32, length: 0), replacement: "я", allowsNewlineFinish: false) == .accept)
    }

    // Вставка після «🇺🇦 » (UTF-16: 5, а не 2) у текст з 29 символів: вставляється одна літера саме там.
    @Test func truncatedPasteAfterEmojiLandsAtTheUTF16Location() {
        let edit = SwitchName.edit(flagged29, range: NSRange(location: 5, length: 0), replacement: "ой", allowsNewlineFinish: false)
        #expect(edit == .replace(text: "🇺🇦 оПеревірила, чи вимкнена пра", cursor: 6))
    }

    // Видалення цілого прапора — як є.
    @Test func deletingWholeEmojiIsAccepted() {
        #expect(SwitchName.edit(flagged29, range: NSRange(location: 0, length: 4), replacement: "", allowsNewlineFinish: false) == .accept)
    }

    // Діапазон, що ріже символ навпіл, розширюється до меж символу: видаляється весь прапор.
    @Test(arguments: [NSRange(location: 9, length: 2), NSRange(location: 7, length: 2), NSRange(location: 8, length: 3)])
    func deletionThatSplitsEmojiRemovesTheWholeCharacter(range: NSRange) {
        let text = "Полила " + flag // UTF-16: 7 + 4
        let edit = SwitchName.edit(text, range: range, replacement: "", allowsNewlineFinish: true)
        #expect(edit == .replace(text: "Полила ", cursor: 7))
    }

    @Test func deletionThatSplitsFamilyRemovesTheWholeCharacter() {
        let text = family + " вдома" // UTF-16: 8 + 6
        // останній член сім'ї: 👧 (UTF-16: 6..<8)
        let edit = SwitchName.edit(text, range: NSRange(location: 6, length: 2), replacement: "", allowsNewlineFinish: false)
        #expect(edit == .replace(text: " вдома", cursor: 0))
    }

    // Курсор (порожній діапазон) усередині символу: вставка йде одразу після цього символу.
    @Test func insertionInsideEmojiGoesAfterIt() {
        let text = "Полила " + flag // UTF-16: 7 + 4
        let edit = SwitchName.edit(text, range: NSRange(location: 9, length: 0), replacement: "x", allowsNewlineFinish: false)
        #expect(edit == .replace(text: "Полила " + flag + "x", cursor: 12))
    }

    // MARK: - Видалення й заміна, що не збільшують текст, — завжди як є (стара довга назва)

    @Test(arguments: [false, true])
    func deletingFromLegacyLongNameIsAccepted(allowsNewlineFinish: Bool) {
        // Backspace у кінці: 51 → 50, усе ще понад межу, але не обрізається до 30.
        let backspace = NSRange(location: utf16Length(legacy51) - 1, length: 1)
        #expect(SwitchName.edit(legacy51, range: backspace, replacement: "", allowsNewlineFinish: allowsNewlineFinish) == .accept)
        // Видалення слова посередині.
        #expect(SwitchName.edit(legacy51, range: NSRange(location: 31, length: 6), replacement: "", allowsNewlineFinish: allowsNewlineFinish) == .accept)
    }

    @Test func replacingInLegacyLongNameWithoutGrowingIsAccepted() {
        // «перед» (5) → «до» (2)
        #expect(SwitchName.edit(legacy51, range: NSRange(location: 31, length: 5), replacement: "до", allowsNewlineFinish: true) == .accept)
        // «перед» (5) → «після» (5)
        #expect(SwitchName.edit(legacy51, range: NSRange(location: 31, length: 5), replacement: "після", allowsNewlineFinish: true) == .accept)
    }

    @Test(arguments: [0, 30, 51])
    func typingIntoLegacyLongNameIsRejected(cursor: Int) {
        let edit = SwitchName.edit(legacy51, range: NSRange(location: cursor, length: 0), replacement: "я", allowsNewlineFinish: true)
        #expect(edit == .reject)
    }

    // Скоротила стару назву до 31 символу — вона й далі лише скорочується: межа — поточна довжина,
    // а не 51, з якої почали.
    @Test func typingIntoShortenedLegacyNameStillOverTheLimitIsRejected() throws {
        let text = String(legacy51.prefix(31))
        try #require(text.count == 31)
        #expect(SwitchName.edit(text, range: endOf(text), replacement: "я", allowsNewlineFinish: false) == .reject)
        #expect(SwitchName.edit(text, range: NSRange(location: 30, length: 1), replacement: "", allowsNewlineFinish: false) == .accept)
    }

    // Вставка з переносами в стару довгу назву: теж не росте.
    @Test(arguments: [false, true])
    func pasteWithNewlinesIntoLegacyLongNameIsRejected(allowsNewlineFinish: Bool) {
        let edit = SwitchName.edit(legacy51, range: endOf(legacy51), replacement: "\nвдома", allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .reject)
    }

    // Заміна виділеного довшою фразою у старій довгій назві: текст не стає довшим за наявні 51 символ —
    // замість 2 виділених стають перші 2 символи вставки.
    @Test func phrasePasteOverSelectionInLegacyLongNameDoesNotGrowIt() {
        // виділено «чи» (UTF-16: 12..<14)
        let edit = SwitchName.edit(legacy51, range: NSRange(location: 12, length: 2), replacement: "аб вгд", allowsNewlineFinish: true)
        #expect(edit == .replace(text: "Перевірила, аб вимкнена праска перед виходом з дому", cursor: 14))
    }

    // Слово поверх слова в старій довгій назві, що зробило б її довшою, — не застосовується.
    @Test func wordPasteOverSelectedWordInLegacyLongNameIsRejected() {
        let edit = SwitchName.edit(legacy51, range: NSRange(location: 12, length: 2), replacement: "абвгд", allowsNewlineFinish: true)
        #expect(edit == .reject)
    }

    // Видалення в повному полі.
    @Test func deletingFromFullFieldIsAccepted() {
        #expect(SwitchName.edit(full30, range: NSRange(location: 29, length: 1), replacement: "", allowsNewlineFinish: false) == .accept)
        #expect(SwitchName.edit(full30, range: NSRange(location: 0, length: 30), replacement: "", allowsNewlineFinish: false) == .accept)
    }

    // MARK: - Переноси рядка

    // «Готово» в полі редагування (`returnKeyType = .done` вставляє «\n») — у будь-якому місці,
    // з виділенням чи без, у порожньому, повному й старому довгому тексті: текст не змінюється, редагування завершується.
    @Test(arguments: ["", "Полила", full30, legacy51])
    func doneKeyFinishesEditing(text: String) {
        #expect(SwitchName.edit(text, range: endOf(text), replacement: "\n", allowsNewlineFinish: true) == .finish)
        #expect(SwitchName.edit(text, range: NSRange(location: 0, length: 0), replacement: "\n", allowsNewlineFinish: true) == .finish)
    }

    @Test func doneKeyWithSelectionFinishesWithoutDeletingSelection() {
        #expect(SwitchName.edit(full30, range: NSRange(location: 12, length: 2), replacement: "\n", allowsNewlineFinish: true) == .finish)
    }

    // Курсор усередині тексту — теж «Готово», навіть у повному полі й старій довгій назві.
    @Test(arguments: [full30, legacy51])
    func doneKeyInTheMiddleFinishesEditing(text: String) {
        #expect(SwitchName.edit(text, range: NSRange(location: 10, length: 0), replacement: "\n", allowsNewlineFinish: true) == .finish)
    }

    // Лише переноси (наприклад, «\r\n» від апаратної клавіатури) — теж «Готово».
    @Test(arguments: ["\r\n", "\n\n", "\r"], ["Полила", legacy51])
    func newlineOnlyReplacementFinishesEditing(replacement: String, text: String) {
        #expect(SwitchName.edit(text, range: endOf(text), replacement: replacement, allowsNewlineFinish: true) == .finish)
    }

    // Вставка з переносами: кожна послідовність переносів — один пробіл; редагування триває.
    // Однаково в обох полях; правку ставить делегат (`.replace`), бо сирі переноси в поле не потрапляють.
    @Test(arguments: [
        ("", 0, "Полила\nквіти", "Полила квіти", 12),
        ("", 0, "Полила\r\nквіти", "Полила квіти", 12),
        ("", 0, "Полила\n\n\nквіти", "Полила квіти", 12),
        ("", 0, "Полила\r\n\r\nквіти", "Полила квіти", 12),
        ("Полила", 6, "\nквіти", "Полила квіти", 12),
        ("Полила", 6, " квіти\n", "Полила квіти ", 13),
        ("квіти", 0, "Полила\n", "Полила квіти", 7),
        ("Газ", 3, "\n\nгорить\n", "Газ горить ", 11),
        ("", 0, "Полила\nквіти\nна балконі", "Полила квіти на балконі", 23),
        ("", 0, "\nквіти", " квіти", 6)
    ] as [(String, Int, String, String, Int)], [false, true])
    func pasteWithNewlinesTurnsEachRunIntoOneSpace(
        sample: (String, Int, String, String, Int), allowsNewlineFinish: Bool
    ) {
        let sample = (text: sample.0, location: sample.1, paste: sample.2, expected: sample.3, cursor: sample.4)
        let edit = SwitchName.edit(
            sample.text, range: NSRange(location: sample.location, length: 0),
            replacement: sample.paste, allowsNewlineFinish: allowsNewlineFinish
        )
        #expect(edit == .replace(text: sample.expected, cursor: sample.cursor))
    }

    // У полі додавання перенос «Готово» не означає: одиничний «\n» стає пробілом.
    @Test func newlineInAddFieldBecomesSpace() {
        let edit = SwitchName.edit("Полила", range: endOf("Полила"), replacement: "\n", allowsNewlineFinish: false)
        #expect(edit == .replace(text: "Полила ", cursor: 7))
    }

    // Після заміни переносів пробілами діє та сама межа.
    @Test(arguments: [false, true])
    func pasteWithNewlinesRespectsTheLimit(allowsNewlineFinish: Bool) {
        let text = String(almost29.dropLast(4)) // 25
        // «аб\n\nвгд» → «аб вгд» (6) → влазить 5: «аб вг»
        let edit = SwitchName.edit(text, range: endOf(text), replacement: "аб\n\nвгд", allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .replace(text: text + "аб вг", cursor: 30))
    }

    @Test func longPasteWithNewlineKeepsItsFirstCharacters() {
        let edit = SwitchName.edit("Полила", range: endOf("Полила"), replacement: "\nквіти у вітальні, на кухні й на балконі", allowsNewlineFinish: false)
        #expect(edit == .replace(text: "Полила квіти у вітальні, на ку", cursor: 30))
    }

    @Test(arguments: [false, true])
    func pasteWithNewlinesIntoFullFieldIsRejected(allowsNewlineFinish: Bool) {
        let edit = SwitchName.edit(full30, range: NSRange(location: 10, length: 0), replacement: "\nвдома\n", allowsNewlineFinish: allowsNewlineFinish)
        #expect(edit == .reject)
    }

    @Test func newlineIntoFullAddFieldIsRejected() {
        #expect(SwitchName.edit(full30, range: endOf(full30), replacement: "\n", allowsNewlineFinish: false) == .reject)
    }

    // MARK: - Некоректний діапазон: не падати, текст не змінювати

    @Test(arguments: [
        NSRange(location: 13, length: 0), // за кінцем
        NSRange(location: 11, length: 2), // кінець за межами
        NSRange(location: NSNotFound, length: 0),
        NSRange(location: NSNotFound, length: 1), // переповнення location + length
        NSRange(location: 0, length: Int.max),
        NSRange(location: -1, length: 1),
        NSRange(location: 2, length: -1)
    ], [false, true])
    func invalidRangeIsRejected(range: NSRange, allowsNewlineFinish: Bool) {
        let text = "Полила квіт" // UTF-16: 11
        #expect(SwitchName.edit(text, range: range, replacement: "и", allowsNewlineFinish: allowsNewlineFinish) == .reject)
        #expect(SwitchName.edit(text, range: range, replacement: "", allowsNewlineFinish: allowsNewlineFinish) == .reject)
    }

    @Test func invalidRangeInEmptyFieldIsRejected() {
        #expect(SwitchName.edit("", range: NSRange(location: 1, length: 0), replacement: "П", allowsNewlineFinish: false) == .reject)
    }

    // MARK: - Інваріант: результат будь-якої правки не довший за max(30, поточна довжина)
    // і курсор `.replace` лежить у межах нового тексту.

    @Test(arguments: [
        ("", "0123456789АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФ"),
        (almost29, family + flag + thumbsUp),
        (full30, "абв"),
        (legacy51, "абв"),
        (flagged29, "абв\nгде"),
        ("Полила", String(repeating: family, count: 40))
    ])
    func noEditGrowsTextBeyondTheLimit(text: String, paste: String) throws {
        let limit = max(SwitchName.maxLength, text.count)
        for location in 0...utf16Length(text) {
            let range = NSRange(location: location, length: 0)
            let edit = SwitchName.edit(text, range: range, replacement: paste, allowsNewlineFinish: false)
            let result = try #require(fieldText(after: edit, text: text, range: range, replacement: paste))
            #expect(result.count <= limit, "location \(location): \(result.count) символів")
            if case .replace(let newText, let cursor) = edit {
                #expect((0...utf16Length(newText)).contains(cursor), "location \(location): курсор \(cursor)")
            }
        }
    }
}

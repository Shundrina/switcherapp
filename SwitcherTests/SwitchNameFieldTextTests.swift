import Testing
@testable import Switcher

// Задача A: що лишається в полі «Назва» після зміни тексту — `SwitchName.fieldText(from:to:)`.
// Функцію викликає `.onChange(of: name)` і у формі додавання, і під час перейменування
// на екрані перемикача: (значення поля до зміни, значення після зміни) → значення поля.

/// Рядок із `count` однакових кириличних літер.
private func letters(_ count: Int) -> String {
    String(repeating: "а", count: count)
}

/// Повне поле: рівно 30 символів.
private let fullName = "Перевірила, чи вимкнена праска"

/// Назва, створена до появи межі: 51 символ.
private let legacyLongName = "Перевірила, чи вимкнена праска перед виходом з дому"

@MainActor
struct SwitchNameFieldTextTests {
    @Test func fixturesHaveExpectedLength() {
        #expect(fullName.count == SwitchName.maxLength)
        #expect(legacyLongName.count > SwitchName.maxLength)
    }

    // Поки межу не перевищено, поле приймає зміну як є: зокрема стирання й заміну
    // тексту в повному полі — повне поле блокує лише нові символи, а не будь-які правки.
    @Test(arguments: [
        ("", "П"),
        ("Полила", "Полила "), // пробіл у кінці не обрізається, інакше не надрукувати наступне слово
        (letters(29), letters(30)), // тридцятий символ
        (fullName, String(fullName.dropLast())), // стерла символ у повному полі
        (fullName, "Перевірила, чи вимкнена прас"), // стерла кілька
        (fullName, "Газ горить"), // виділила все й замінила коротшим
        ("Газ", "")
    ])
    func changeWithinLimitIsAccepted(old: String, new: String) {
        #expect(SwitchName.fieldText(from: old, to: new) == new)
    }

    // Головний сценарій бага: у повне поле нові символи не вводяться — поле лишається
    // попереднім значенням, і з кінця нічого мовчки не зникає.
    @Test(arguments: [
        "Перевірила, чи увимкнена праска", // літера всередині тексту
        "Я" + fullName, // на початку
        fullName + "я", // у кінці
        fullName + " ", // пробіл у кінці
        "Перевірила, чи не вимкнена праска" // вставлене слово всередині
    ])
    func newCharactersAreNotTypedIntoFullField(new: String) {
        #expect(SwitchName.fieldText(from: fullName, to: new) == fullName)
    }

    // Автозаміна підставляє довше слово: у повному полі «квти» → «квіти» не застосовується,
    // а не обрізає останню літеру «кухні».
    @Test func autocorrectToLongerWordInFullFieldIsRejected() throws {
        let typed = "Полила квти на балконі й кухні"
        try #require(typed.count == SwitchName.maxLength)

        #expect(SwitchName.fieldText(from: typed, to: "Полила квіти на балконі й кухні") == typed)
    }

    // Вставка в неповне поле, як і досі, лишає перші 30 символів нового тексту
    // (пробіл на межі в полі не обрізається — це робить лише збереження).
    @Test(arguments: [
        ("Полила квіти", "Полила у вітальні, на кухні й на балконі квіти", "Полила у вітальні, на кухні й "),
        ("", legacyLongName, "Перевірила, чи вимкнена праска"),
        (letters(29), letters(29) + "ям", letters(29) + "я") // неповне поле: 29 → 31
    ])
    func pasteIntoFieldThatIsNotFullKeepsFirstThirtyCharacters(old: String, new: String, expected: String) {
        #expect(SwitchName.fieldText(from: old, to: new) == expected)
    }

    // Межа рахується в символах, які бачить людина: складена графема тридцятим символом
    // лишається цілою, коли всередину повного поля пробують вписати літеру.
    @Test(arguments: [
        "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", // родина через ZWJ
        "\u{1F1FA}\u{1F1E6}", // прапор України
        "\u{438}\u{306}" // «й» як «и» + знак бревіса
    ])
    func clusterAtTheLimitStaysWholeInFullField(cluster: String) {
        let old = letters(29) + cluster
        let new = letters(10) + "я" + letters(19) + cluster

        #expect(SwitchName.fieldText(from: old, to: new) == old)
    }

    // Знак, що зливається з останнім символом повного поля, не додає нового символу:
    // «и» + бревіс → «й», «палець угору» + тон шкіри — у полі й далі 30 символів.
    @Test(arguments: [
        ("\u{438}", "\u{438}\u{306}"),
        ("\u{1F44D}", "\u{1F44D}\u{1F3FD}")
    ])
    func combiningMarkThatAddsNoCharacterIsAcceptedInFullField(last: String, combined: String) {
        let old = letters(29) + last
        let new = letters(29) + combined

        #expect(SwitchName.fieldText(from: old, to: new) == new)
    }

    // Стара назва, довша за межу (створена до обмеження). Повертати `old` тут не можна —
    // поле лишилося б понад межею. Будь-яка правка — і дописування, і стирання — лишає
    // перші 30 символів нового тексту, а не блокується.
    @Test(arguments: [
        (legacyLongName + "!", "Перевірила, чи вимкнена праска"), // дописала в кінці
        ("Перевірила, чи не вимкнена праска перед виходом з дому", "Перевірила, чи не вимкнена пра"), // всередині
        (String(legacyLongName.dropLast()), "Перевірила, чи вимкнена праска"), // стерла останній символ
        ("Перевірила, чи праска перед виходом з дому", "Перевірила, чи праска перед ви") // стерла слово
    ])
    func editingLegacyLongNameAppliesTheLimit(new: String, expected: String) {
        #expect(SwitchName.fieldText(from: legacyLongName, to: new) == expected)
    }
}

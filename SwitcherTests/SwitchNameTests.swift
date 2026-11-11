import Foundation
import SwiftData
import Testing
@testable import Switcher

/// Складені графеми: людина бачить один символ, а в рядку це кілька скалярів Unicode.
/// Записані кодами, щоб редактор не міг непомітно змінити їхній склад.
private let graphemeClusters = [
    "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", // родина: чотири емодзі через ZWJ
    "\u{1F1FA}\u{1F1E6}", // прапор України: два регіональні індикатори
    "\u{1F44D}\u{1F3FD}", // «палець угору» з тоном шкіри
    "\u{438}\u{306}", // «й» як «и» + окремий знак бревіса
    "\u{456}\u{308}" // «ї» як «і» + окремі дві крапки
]

/// Рядок із `count` однакових кириличних літер.
private func letters(_ count: Int) -> String {
    String(repeating: "а", count: count)
}

/// Вимога 1: межа довжини назви — одне число на поле, лічильник і збереження.
@MainActor
struct SwitchNameMaxLengthTests {
    @Test func maxLengthIsThirtyCharacters() {
        #expect(SwitchName.maxLength == 30)
    }
}

/// Вимоги 2 і 3: що лишається в полі «Назва» після кожної зміни тексту.
@MainActor
struct SwitchNameLimitedTests {
    // Поки межу не перевищено, поле нічого не чіпає — зокрема пробіли по краях:
    // інакше після слова не можна було б надрукувати пробіл перед наступним.
    @Test(arguments: ["", "Полила квіти", "Полила ", "  Квіти", letters(29), letters(30)])
    func textWithinLimitIsKeptAsIs(text: String) {
        #expect(SwitchName.limited(text) == text)
    }

    // Друкують: у полі вже 30 символів, тридцять перший не з'являється.
    @Test func thirtyFirstTypedCharacterIsCutOff() {
        #expect(SwitchName.limited(letters(30) + "я") == letters(30))
    }

    // Вставляють: із значно довшого тексту лишаються перші 30 символів.
    @Test func pastedLongTextKeepsFirstThirtyCharacters() {
        let pasted = "Перевірила, чи вимкнена праска перед виходом з дому, і зачинила двері на обидва замки"

        #expect(SwitchName.limited(pasted) == "Перевірила, чи вимкнена праска")
    }

    // Рахуються символи, які бачить людина, а не скаляри чи кодові одиниці:
    // тридцять складених графем — це рівно 30 символів, вони вміщаються всі.
    @Test(arguments: graphemeClusters)
    func thirtyGraphemeClustersFit(cluster: String) {
        let text = String(repeating: cluster, count: 30)

        #expect(SwitchName.limited(text) == text)
    }

    // Складена графема на межі (тридцятий символ) лишається цілою, а не розривається
    // навпіл; усе після неї відтинається.
    @Test(arguments: graphemeClusters)
    func clusterAsThirtiethCharacterIsKeptWhole(cluster: String) {
        #expect(SwitchName.limited(letters(29) + cluster + "я") == letters(29) + cluster)
    }

    // Тридцять перша складена графема відтинається повністю, без «уламків».
    @Test(arguments: graphemeClusters)
    func thirtyFirstClusterIsCutOffWhole(cluster: String) {
        let text = String(repeating: cluster, count: 31)

        #expect(SwitchName.limited(text) == String(repeating: cluster, count: 30))
    }
}

/// Вимога 4: лічильник під полем і його опис для VoiceOver.
/// Рахують те саме, що обмежує поле: усі символи в полі, разом із пробілами по краях, —
/// інакше поле перестало б приймати текст, коли лічильник ще не дійшов до 30.
@MainActor
struct SwitchNameCounterTests {
    @Test(arguments: [
        ("", "0 / 30"),
        ("Полила квіти", "12 / 30"),
        (letters(30), "30 / 30")
    ])
    func counterShowsTypedAndMaximum(text: String, expected: String) {
        #expect(SwitchName.counterText(for: text) == expected)
    }

    @Test(arguments: graphemeClusters)
    func counterCountsGraphemeClusterAsOneCharacter(cluster: String) {
        #expect(SwitchName.counterText(for: cluster) == "1 / 30")
    }

    @Test func counterCountsSpacesAtTheEdges() {
        #expect(SwitchName.counterText(for: "  Квіти ") == "8 / 30")
    }

    // Форма «Символів: N з 30» однакова для будь-якого числа — не треба узгоджувати
    // іменник із числівником («1 символ», «2 символи», «5 символів»).
    @Test(arguments: [
        ("", "Символів: 0 з 30"),
        ("я", "Символів: 1 з 30"),
        ("Так", "Символів: 3 з 30"),
        ("Полила квіти", "Символів: 12 з 30"),
        (letters(30), "Символів: 30 з 30")
    ])
    func accessibilityLabelSpellsOutTheCounter(text: String, expected: String) {
        #expect(SwitchName.counterAccessibilityLabel(for: text) == expected)
    }

    // VoiceOver називає те саме число, яке видно в лічильнику.
    @Test(arguments: graphemeClusters)
    func accessibilityLabelCountsGraphemeClusterAsOneCharacter(cluster: String) {
        #expect(SwitchName.counterAccessibilityLabel(for: cluster) == "Символів: 1 з 30")
    }

    @Test func accessibilityLabelCountsSpacesAtTheEdges() {
        #expect(SwitchName.counterAccessibilityLabel(for: "  Квіти ") == "Символів: 8 з 30")
    }
}

/// Вимога 5: назва, яка потрапляє в `SwitchItem`, — без пробілів і переносів по краях
/// і не довша за 30 символів.
@MainActor
struct SwitchNameForSavingTests {
    @Test(arguments: [
        ("Полила квіти", "Полила квіти"),
        ("  Полила квіти  ", "Полила квіти"),
        ("\nГаз горить\n", "Газ горить"),
        (" \n Двері  зачинені \n ", "Двері  зачинені")
    ])
    func edgeWhitespaceIsTrimmedAndInnerIsKept(text: String, expected: String) {
        #expect(SwitchName.forSaving(text) == expected)
    }

    // Із самих пробілів назви не виходить: результат порожній, і за ним форма
    // тримає кнопку «Додати» вимкненою (як зараз за `trimmedName.isEmpty`).
    @Test(arguments: ["", "   ", "\n", String(repeating: " ", count: 30)])
    func blankTextGivesEmptyName(text: String) {
        #expect(SwitchName.forSaving(text) == "")
    }

    @Test func nameOfExactlyThirtyCharactersIsSavedWhole() {
        #expect(SwitchName.forSaving(letters(30)) == letters(30))
    }

    // Поле не пропускає понад 30 символів, але збереження не покладається на це.
    @Test func longerNameIsCutToFirstThirtyCharacters() {
        let text = "Перевірила, чи вимкнена праска перед виходом з дому"

        #expect(SwitchName.forSaving(text) == "Перевірила, чи вимкнена праска")
    }

    // Пробіли по краях — не частина назви й не витрачають межу: спершу обрізаються
    // вони, і лише потім рахуються 30 символів.
    @Test func edgeWhitespaceDoesNotCountTowardsTheLimit() {
        #expect(SwitchName.forSaving("   " + letters(30) + "  ") == letters(30))
    }

    // Якщо межа припала на пробіл між словами, він не лишається в кінці назви:
    // тридцятий символ тут — пробіл після «плита».
    @Test func cutDoesNotLeaveSpaceAtTheEnd() {
        #expect(SwitchName.forSaving("Перевірила, чи вимкнена плита вдома") == "Перевірила, чи вимкнена плита")
    }

    // Збереження рахує символи так само, як поле: складена графема на межі лишається цілою.
    @Test(arguments: graphemeClusters)
    func clusterAsThirtiethCharacterIsKeptWhole(cluster: String) {
        #expect(SwitchName.forSaving("  " + letters(29) + cluster + "я  ") == letters(29) + cluster)
    }
}

/// Вимога 6: межа діє лише на введення у формі. Перемикачі, створені до неї,
/// лишаються з довгими назвами — модель нічого не обрізає ні під час створення,
/// ні під час читання зі сховища.
@MainActor
struct SwitchNameExistingItemsTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    @Test func longNameOfExistingSwitchIsLeftAsIs() throws {
        let longName = "Перевірила, чи вимкнена праска перед виходом з дому"
        try #require(longName.count > 30)

        let item = SwitchItem(name: longName)
        #expect(item.name == longName)

        context.insert(item)
        try context.save()
        let stored = try ModelContext(container).fetch(FetchDescriptor<SwitchItem>())
        #expect(stored.map(\.name) == [longName])
    }
}

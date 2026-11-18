import Foundation
import Testing
@testable import Switcher

// Примітка до перемикача — `SwitchNote`: межа довжини, лічильник під полем і текст для збереження.
// Так само, як `SwitchName` для назви, але межа — 200 символів, а примітка багаторядкова:
// переноси рядка всередині тексту — її частина (кожен рахується як один символ), а на краях
// обрізаються разом із пробілами.

/// Складені графеми: людина бачить один символ, а в рядку це кілька скалярів Unicode.
private let graphemeClusters = [
    "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", // родина: чотири емодзі через ZWJ
    "\u{1F1FA}\u{1F1E6}", // прапор України
    "\u{1F44D}\u{1F3FD}", // «палець угору» з тоном шкіри
    "\u{438}\u{306}", // «й» як «и» + бревіс
    "\u{456}\u{308}" // «ї» як «і» + дві крапки
]

/// Рядок із `count` однакових кириличних літер.
private func letters(_ count: Int) -> String {
    String(repeating: "а", count: count)
}

@MainActor
struct SwitchNoteMaxLengthTests {
    @Test func maxLengthIsTwoHundredCharacters() {
        #expect(SwitchNote.maxLength == 200)
    }

    // Межа назви не змінилася.
    @Test func nameLimitIsStillThirty() {
        #expect(SwitchName.maxLength == 30)
    }
}

/// Лічильник під полем примітки: «12 / 200» на екрані, «Символів: 12 з 200» для VoiceOver —
/// так само, як у назви. Рахує всі символи в полі, разом із пробілами й переносами.
@MainActor
struct SwitchNoteCounterTests {
    @Test(arguments: [
        ("", "0 / 200"),
        ("Полила квіти", "12 / 200"),
        ("Рядок 1\nРядок 2", "15 / 200"),
        (letters(200), "200 / 200")
    ])
    func counterShowsTypedAndMaximum(text: String, expected: String) {
        #expect(SwitchNote.counterText(for: text) == expected)
    }

    @Test(arguments: [
        ("", "Символів: 0 з 200"),
        ("я", "Символів: 1 з 200"),
        ("Полила квіти", "Символів: 12 з 200"),
        ("Рядок 1\nРядок 2", "Символів: 15 з 200"),
        (letters(200), "Символів: 200 з 200")
    ])
    func accessibilityLabelSpellsOutTheCounter(text: String, expected: String) {
        #expect(SwitchNote.counterAccessibilityLabel(for: text) == expected)
    }

    // Перенос рядка — один символ, і «\r\n» теж (один `Character`).
    @Test(arguments: ["\n", "\r\n", "\r"])
    func newlineCountsAsOneCharacter(newline: String) {
        #expect(SwitchNote.counterText(for: "а" + newline + "б") == "3 / 200")
        #expect(SwitchNote.counterAccessibilityLabel(for: "а" + newline + "б") == "Символів: 3 з 200")
    }

    @Test(arguments: graphemeClusters)
    func counterCountsGraphemeClusterAsOneCharacter(cluster: String) {
        #expect(SwitchNote.counterText(for: cluster) == "1 / 200")
        #expect(SwitchNote.counterAccessibilityLabel(for: cluster) == "Символів: 1 з 200")
    }

    @Test func counterCountsSpacesAndNewlinesAtTheEdges() {
        #expect(SwitchNote.counterText(for: "  Квіти \n") == "9 / 200")
        #expect(SwitchNote.counterAccessibilityLabel(for: "  Квіти \n") == "Символів: 9 з 200")
    }
}

/// Примітка, яка потрапляє в `SwitchItem`: без пробілів і переносів по краях, переноси й пробіли
/// всередині — як є, не довша за 200 символів. З самих пробілів і переносів — порожня (примітки немає).
@MainActor
struct SwitchNoteForSavingTests {
    @Test(arguments: [
        ("Поливати раз на тиждень", "Поливати раз на тиждень"),
        ("  Поливати раз на тиждень  ", "Поливати раз на тиждень"),
        ("\nПоливати\nпо суботах\n\n", "Поливати\nпо суботах"),
        (" \r\n Рядок 1\n\nРядок 2 \n", "Рядок 1\n\nРядок 2"),
        ("Двері  зачинені", "Двері  зачинені")
    ])
    func edgeWhitespaceIsTrimmedAndInnerIsKept(text: String, expected: String) {
        #expect(SwitchNote.forSaving(text) == expected)
    }

    @Test(arguments: ["", " ", "   ", "\n", "\r\n", " \n \r\n ", "\n\n\n", String(repeating: " ", count: 250)])
    func blankTextGivesEmptyNote(text: String) {
        #expect(SwitchNote.forSaving(text) == "")
    }

    @Test func noteOfExactlyTwoHundredCharactersIsSavedWhole() {
        #expect(SwitchNote.forSaving(letters(200)) == letters(200))
    }

    // Поле не пропускає понад 200 символів, але збереження не покладається на це.
    @Test func longerNoteIsCutToFirstTwoHundredCharacters() {
        #expect(SwitchNote.forSaving(letters(200) + "бвг") == letters(200))
        #expect(SwitchNote.forSaving(letters(150) + "\n" + letters(100)) == letters(150) + "\n" + letters(49))
    }

    // Пробіли й переноси по краях не витрачають межу: спершу обрізаються вони.
    @Test func edgeWhitespaceDoesNotCountTowardsTheLimit() {
        #expect(SwitchNote.forSaving("  \n" + letters(200) + " \n") == letters(200))
    }

    // Якщо межа припала на пробіл чи перенос, він не лишається в кінці примітки.
    @Test(arguments: [" ", "\n"])
    func cutDoesNotLeaveWhitespaceAtTheEnd(separator: String) {
        let text = letters(199) + separator + "кінець"
        #expect(SwitchNote.forSaving(text) == letters(199))
    }

    @Test(arguments: graphemeClusters)
    func clusterAsTwoHundredthCharacterIsKeptWhole(cluster: String) {
        #expect(SwitchNote.forSaving(" " + letters(199) + cluster + "я ") == letters(199) + cluster)
    }

    // «\r\n» усередині — один символ: 198 + «\r\n» + 1 = 200, влазить усе.
    @Test func crlfInsideCountsAsOneCharacter() {
        let text = letters(198) + "\r\n" + "б"
        #expect(text.count == 200)
        #expect(SwitchNote.forSaving(text) == text)
    }
}

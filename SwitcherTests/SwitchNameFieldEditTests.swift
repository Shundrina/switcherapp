import Foundation
import SwiftData
import Testing
@testable import Switcher

// Баг-фікс за знахідками reviewer: що робить поле назви на екрані перемикача, коли
// в тексті з'являється перенос рядка — `SwitchName.fieldEdit(from:to:)`.
// Поле багаторядкове (`TextField(axis: .vertical)`), тож «Готово» на клавіатурі вставляє
// перенос, а вставка з буфера чи диктування «новий рядок» — теж приносять переноси.
// `.onChange(of: draft)` викликає функцію з (значення поля до зміни, після зміни) і отримує
// новий текст поля й ознаку «завершити редагування».

/// Повне поле: рівно 30 символів.
private let fullName = "Перевірила, чи вимкнена праска"

/// Назва, створена до появи межі: 51 символ.
private let legacyLongName = "Перевірила, чи вимкнена праска перед виходом з дому"

/// Вставляє `insertion` у `text` перед символом з індексом `offset`.
private func inserting(_ insertion: String, into text: String, at offset: Int) -> String {
    let index = text.index(text.startIndex, offsetBy: offset)
    return String(text[..<index]) + insertion + String(text[index...])
}

@MainActor
struct SwitchNameFieldEditTests {
    @Test func fixturesHaveExpectedLength() {
        #expect(fullName.count == SwitchName.maxLength)
        #expect(legacyLongName.count == 51)
    }

    // Без переносів — та сама поведінка, що й досі: `fieldText(from:to:)`, редагування триває.
    @Test(arguments: [
        ("", "П"),
        ("Полила", "Полила "),
        (fullName, fullName + "я"), // у повне поле нові символи не вводяться
        ("Полила квіти", "Полила у вітальні, на кухні й на балконі квіти"), // вставка понад межу
        (legacyLongName, String(legacyLongName.dropLast())),
        ("Газ", "")
    ])
    func changeWithoutNewlinesBehavesLikeFieldText(old: String, new: String) {
        let edit = SwitchName.fieldEdit(from: old, to: new)

        #expect(edit.text == SwitchName.fieldText(from: old, to: new))
        #expect(!edit.finishesEditing)
    }

    // Баг 2: «Готово» — до тексту додано лише перенос(и). Поле не змінюється взагалі
    // (жодної межі), редагування завершується. Стара назва понад 30 символів лишається повною.
    @Test(arguments: ["", "Полила", fullName, legacyLongName])
    func doneKeyAtTheEndKeepsTextUnchangedAndFinishes(old: String) {
        let edit = SwitchName.fieldEdit(from: old, to: old + "\n")

        #expect(edit.text == old)
        #expect(edit.finishesEditing)
    }

    // Кілька переносів (наприклад, «Готово» спрацювало двічі або «\r\n») — так само «Готово».
    @Test(arguments: [
        ("Полила", "Полила\n\n"),
        ("Полила", "Полила\r\n"),
        ("Полила", "\nПолила\n"),
        (legacyLongName, legacyLongName + "\n\n")
    ])
    func severalNewlinesWithoutOtherChangesFinish(old: String, new: String) {
        let edit = SwitchName.fieldEdit(from: old, to: new)

        #expect(edit.text == old)
        #expect(edit.finishesEditing)
    }

    // «Готово» незалежно від того, де стоїть курсор: на початку, всередині, в кінці.
    @Test(arguments: [fullName, legacyLongName], [0, 10, 30])
    func doneKeyAnywhereInTextKeepsTextUnchangedAndFinishes(old: String, cursor: Int) {
        let edit = SwitchName.fieldEdit(from: old, to: inserting("\n", into: old, at: cursor))

        #expect(edit.text == old)
        #expect(edit.finishesEditing)
    }

    // Баг 1: вставка чи диктування з переносами. Кожна послідовність переносів стає одним
    // пробілом — слова не склеюються, — і редагування НЕ завершується (клавіатура лишається).
    // Пробіли по краях у полі допустимі: їх прибирає `forSaving` під час збереження.
    @Test(arguments: [
        ("Полила", "Полила\nквіти", "Полила квіти"), // вставила «\nквіти» в кінці
        ("", "Полила\nквіти\nна балконі", "Полила квіти на балконі"), // кілька рядків у порожнє поле
        ("", "\nквіти", " квіти"), // перенос на початку вставленого фрагмента
        ("Полила", "Полила квіти\n", "Полила квіти "), // перенос у кінці вставленого фрагмента
        ("квіти", "Полила\nквіти", "Полила квіти"), // вставила «Полила\n» перед курсором на початку
        ("", "Полила\r\nквіти", "Полила квіти"), // переноси Windows
        ("", "Полила\n\n\nквіти", "Полила квіти"), // кілька переносів поспіль
        ("", "Полила\r\n\r\nквіти", "Полила квіти"),
        ("Газ", "Газ\n\nгорить\n", "Газ горить ")
    ])
    func pasteWithNewlinesReplacesThemWithSpacesAndKeepsEditing(old: String, new: String, expected: String) {
        let edit = SwitchName.fieldEdit(from: old, to: new)

        #expect(edit.text == expected)
        #expect(!edit.finishesEditing)
    }

    // Вставка з переносами підкоряється тим самим правилам межі, що й `fieldText`.
    @Test(arguments: [
        // неповне поле: лишаються перші 30 символів
        ("Полила", "Полила\nквіти у вітальні, на кухні й на балконі", "Полила квіти у вітальні, на ку"),
        // повне поле: нові символи не вводяться
        (fullName, fullName + "\nвдома", fullName),
        (fullName, inserting("\nвдома\n", into: fullName, at: 10), fullName),
        // стара довга назва: будь-яка правка лишає перші 30 символів
        (legacyLongName, legacyLongName + "\nвдома", "Перевірила, чи вимкнена праска")
    ])
    func pasteWithNewlinesRespectsTheLimit(old: String, new: String, expected: String) {
        let edit = SwitchName.fieldEdit(from: old, to: new)

        #expect(edit.text == expected)
        #expect(!edit.finishesEditing)
    }
}

// Наскрізні сценарії: поле → `SwitchItem.rename(to:)` (SwiftData у пам'яті).
@MainActor
struct SwitchNameFieldEditRenameTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    // Баг 2: торкнулася старої довгої назви й одразу натиснула «Готово» — назва лишається повною,
    // так само як після дотику поза полем.
    @Test func doneKeyRightAwayKeepsLegacyLongNameWhole() throws {
        let item = SwitchItem(name: legacyLongName)
        context.insert(item)
        try context.save()

        let edit = SwitchName.fieldEdit(from: item.name, to: item.name + "\n")
        #expect(edit.finishesEditing)
        item.rename(to: edit.text)

        #expect(item.name == legacyLongName)
        try context.save()
        #expect(try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).map(\.name) == [legacyLongName])
    }

    // Баг 1: дописала до «Полила» вставку «\nквіти», потім «Готово» — назва «Полила квіти»,
    // а не «Полилаквіти»; вставка сама редагування не завершує.
    @Test func pasteWithNewlineThenDoneKeepsWordsApart() {
        let item = SwitchItem(name: "Полила")
        context.insert(item)

        let paste = SwitchName.fieldEdit(from: "Полила", to: "Полила\nквіти")
        #expect(!paste.finishesEditing)

        let done = SwitchName.fieldEdit(from: paste.text, to: paste.text + "\n")
        #expect(done.finishesEditing)
        item.rename(to: done.text)

        #expect(item.name == "Полила квіти")
    }
}

// `rename(to:)`: якщо текст поля відрізняється від назви лише пробілами чи переносами по краях,
// назва для збереження та сама — модель не має позначатися зміненою (SwiftData позначає її
// зміненою навіть після присвоєння того самого значення).
@MainActor
struct SwitchRenameSameNameTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    @Test(arguments: ["Полила квіти ", " Полила квіти", "Полила квіти\n", "  Полила квіти  "])
    func textThatSavesAsTheSameNameLeavesModelUnchanged(text: String) throws {
        let item = SwitchItem(name: "Полила квіти")
        context.insert(item)
        try context.save()
        try #require(!context.hasChanges)

        item.rename(to: text)

        #expect(item.name == "Полила квіти")
        #expect(!item.hasChanges)
        #expect(!context.hasChanges)
    }
}

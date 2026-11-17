import Foundation
import SwiftData
import Testing
@testable import Switcher

// Задача B: перейменування на екрані перемикача — `SwitchItem.rename(to:)`.
// Екран викликає його з текстом поля, коли редагування завершується
// («Готово», втрата фокуса, вихід з екрана).

/// Назва, створена до появи межі: 55 символів, тридцятий — пробіл після «плита».
private let legacyLongName = "Перевірила, чи вимкнена плита вдома і чи зачинила вікна"

@MainActor
struct SwitchItemRenameTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(name: String) -> SwitchItem {
        let item = SwitchItem(name: name)
        context.insert(item)
        return item
    }

    // Вимога 3: зберігається `SwitchName.forSaving(текст)` — без пробілів і переносів
    // по краях і не довше за 30 символів (пробіл на межі не лишається в кінці).
    @Test(arguments: [
        ("Полила вазони", "Полила вазони"),
        ("  Полила вазони \n", "Полила вазони"),
        ("Перевірила, чи вимкнена плита вдома", "Перевірила, чи вимкнена плита")
    ])
    func renameSavesNameForSaving(text: String, expected: String) {
        let item = makeItem(name: "Полила квіти")

        item.rename(to: text)

        #expect(item.name == expected)
    }

    // Вимога 3: порожніх назв не буває — якщо після обрізання нічого не лишилося,
    // назва повертається до попередньої (і стара довга назва при цьому не обрізається).
    @Test(arguments: ["", "   ", "\n", " \n "], ["Полила квіти", legacyLongName])
    func blankTextKeepsPreviousName(text: String, previous: String) {
        let item = makeItem(name: previous)

        item.rename(to: text)

        #expect(item.name == previous)
    }

    // Вимога 4: почала й завершила редагування старої довгої назви без змін —
    // назва лишається повною, межу не застосовано.
    @Test func unchangedLegacyLongNameStaysWhole() throws {
        let item = makeItem(name: legacyLongName)
        try context.save()

        item.rename(to: legacyLongName)

        #expect(item.name == legacyLongName)
        try context.save()
        #expect(try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).map(\.name) == [legacyLongName])
    }

    // Вимога 4 (рішення «скорочувати вручну»): стару довгу назву в полі можна лише скорочувати,
    // поле її не обрізає. Стерла останній символ — у полі 54 символи; «Готово» зберігає перші 30
    // (без пробілу в кінці). Те, що поле збігається з початком старої назви, не означає «без змін».
    @Test func editedLegacyLongNameIsLimitedOnSave() throws {
        let item = makeItem(name: legacyLongName)
        let backspace = NSRange(location: (legacyLongName as NSString).length - 1, length: 1)

        let edit = SwitchName.edit(legacyLongName, range: backspace, replacement: "", allowsNewlineFinish: true)
        #expect(edit == .accept)
        let field = (legacyLongName as NSString).replacingCharacters(in: backspace, with: "")
        #expect(field.count == 54)
        #expect(SwitchName.edit(field, range: NSRange(location: 0, length: 0), replacement: "\n", allowsNewlineFinish: true) == .finish)

        item.rename(to: field)

        #expect(item.name == "Перевірила, чи вимкнена плита")
        try context.save()
        #expect(try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).map(\.name) == ["Перевірила, чи вимкнена плита"])
    }

    // Торкнулася старої довгої назви й одразу натиснула «Готово» — назва лишається повною.
    @Test func doneKeyRightAwayKeepsLegacyLongNameWhole() throws {
        let item = makeItem(name: legacyLongName)
        try context.save()

        let edit = SwitchName.edit(item.name, range: NSRange(location: (item.name as NSString).length, length: 0), replacement: "\n", allowsNewlineFinish: true)
        #expect(edit == .finish)
        item.rename(to: legacyLongName) // `.finish`: текст поля не змінився

        #expect(item.name == legacyLongName)
        try context.save()
        #expect(try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).map(\.name) == [legacyLongName])
    }

    // Дописала до «Полила» вставку «\nквіти», потім «Готово» — назва «Полила квіти»,
    // а не «Полилаквіти»; вставка сама редагування не завершує.
    @Test func pasteWithNewlineThenDoneKeepsWordsApart() throws {
        let item = makeItem(name: "Полила")

        let paste = SwitchName.edit("Полила", range: NSRange(location: 6, length: 0), replacement: "\nквіти", allowsNewlineFinish: true)
        guard case .replace(let field, _) = paste else {
            Issue.record("очікувався .replace, а не \(paste)")
            return
        }
        #expect(field == "Полила квіти")
        #expect(SwitchName.edit(field, range: NSRange(location: 12, length: 0), replacement: "\n", allowsNewlineFinish: true) == .finish)
        item.rename(to: field)

        #expect(item.name == "Полила квіти")
    }

    // Вимога 5: перейменування не створює подій історії й не змінює стан, час
    // останнього перемикання, значок, колір і дату створення — ні в контексті, ні у сховищі.
    @Test func renameLeavesStateHistoryAndAppearanceUntouched() throws {
        let createdAt = TestClock.date(day: 1, hour: 9, minute: 0)
        let toggles = [
            TestClock.date(day: 8, hour: 7, minute: 0),
            TestClock.date(day: 9, hour: 12, minute: 45),
            TestClock.date(day: 10, hour: 23, minute: 59)
        ]
        let flame = try #require(SwitchIcon(rawValue: "🔥"))
        let item = SwitchItem(name: "Газ горить", icon: flame, tone: .coral, createdAt: createdAt)
        context.insert(item)
        for (index, date) in toggles.enumerated() {
            item.setOn(index.isMultiple(of: 2), at: date)
        }
        try context.save()

        item.rename(to: "Плита вимкнена")

        func expectUntouched(_ item: SwitchItem, in context: ModelContext) throws {
            #expect(item.name == "Плита вимкнена")
            #expect(item.isOn)
            #expect(item.lastToggledAt == toggles[2])
            #expect(item.icon == flame)
            #expect(item.tone == .coral)
            #expect(item.createdAt == createdAt)
            let events = try context.fetch(FetchDescriptor<SwitchEvent>(sortBy: [SortDescriptor(\.timestamp)]))
            #expect(events.map(\.timestamp) == toggles)
            #expect(events.map(\.isOn) == [true, false, true])
            #expect(item.sortedEvents.map(\.timestamp) == Array(toggles.reversed()))
        }

        try expectUntouched(item, in: context)

        try context.save()
        let store = ModelContext(container)
        let stored = try #require(try store.fetch(FetchDescriptor<SwitchItem>()).first)
        try expectUntouched(stored, in: store)
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

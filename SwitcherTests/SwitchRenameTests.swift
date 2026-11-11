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

    // Вимога 4: будь-яка правка старої довгої назви застосовує межу. Стерла останній
    // символ — поле одразу показує перші 30 символів, і саме вони (без пробілу в кінці)
    // стають назвою. Те, що поле збігається з початком старої назви, не означає «без змін».
    @Test func editedLegacyLongNameIsLimited() {
        let item = makeItem(name: legacyLongName)
        let field = SwitchName.fieldText(from: legacyLongName, to: String(legacyLongName.dropLast()))

        item.rename(to: field)

        #expect(item.name == "Перевірила, чи вимкнена плита")
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
        let item = SwitchItem(name: "Газ горить", icon: .flame, tone: .coral, createdAt: createdAt)
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
            #expect(item.icon == .flame)
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

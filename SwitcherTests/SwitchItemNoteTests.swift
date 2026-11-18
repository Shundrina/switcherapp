import Foundation
import SwiftData
import Testing
@testable import Switcher

// Примітка в моделі: поле `SwitchItem.note` (за замовчуванням `""` — сумісність із CloudKit; наявні
// перемикачі отримують порожню примітку) і `SwitchItem.updateNote(to:)`, який екран перемикача
// викликає з текстом поля, коли редагування примітки завершується.

@MainActor
struct SwitchItemNoteTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(name: String = "Полила квіти", note: String? = nil) -> SwitchItem {
        let item = SwitchItem(name: name)
        context.insert(item)
        if let note { item.note = note }
        return item
    }

    private func storedNotes() throws -> [String] {
        try ModelContext(container).fetch(FetchDescriptor<SwitchItem>()).map(\.note)
    }

    // MARK: - Значення за замовчуванням

    @Test func newItemHasEmptyNote() throws {
        let item = makeItem()
        #expect(item.note == "")

        try context.save()
        #expect(try storedNotes() == [""])
    }

    // MARK: - Збереження з поля: `SwitchNote.forSaving`

    @Test(arguments: [
        ("Поливати раз на тиждень", "Поливати раз на тиждень"),
        ("  Поливати раз на тиждень \n", "Поливати раз на тиждень"),
        ("\nПоливати\nпо суботах\n", "Поливати\nпо суботах"),
        (String(repeating: "а", count: 210), String(repeating: "а", count: 200))
    ])
    func updateNoteSavesNoteForSaving(text: String, expected: String) throws {
        let item = makeItem()

        item.updateNote(to: text)

        #expect(item.note == expected)
        try context.save()
        #expect(try storedNotes() == [expected])
    }

    // Примітка з самих пробілів і переносів — порожня: так примітку прибирають (на відміну від назви,
    // яка в такому разі лишається попередньою).
    @Test(arguments: ["", "   ", "\n", " \n\r\n "])
    func blankTextRemovesTheNote(text: String) throws {
        let item = makeItem(note: "Поливати раз на тиждень")
        try context.save()

        item.updateNote(to: text)

        #expect(item.note == "")
        try context.save()
        #expect(try storedNotes() == [""])
    }

    @Test func updateNoteReplacesExistingNote() {
        let item = makeItem(note: "Поливати раз на тиждень")

        item.updateNote(to: "Поливати двічі на тиждень")

        #expect(item.note == "Поливати двічі на тиждень")
    }

    // Зміна примітки не створює подій історії й не змінює назву, стан, час останнього перемикання,
    // значок, колір і дату створення — ні в контексті, ні у сховищі.
    @Test func updateNoteLeavesNameStateHistoryAndAppearanceUntouched() throws {
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

        item.updateNote(to: "Перевірити\nперед сном")

        func expectUntouched(_ item: SwitchItem, in context: ModelContext) throws {
            #expect(item.note == "Перевірити\nперед сном")
            #expect(item.name == "Газ горить")
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

    // Текст, що після обрізання країв дає ту саму примітку (зокрема порожнє поле без примітки), —
    // модель не позначається зміненою (SwiftData позначає навіть після присвоєння того самого значення).
    @Test(arguments: [
        ("Поливати\nпо суботах", "Поливати\nпо суботах"),
        ("Поливати\nпо суботах", " Поливати\nпо суботах\n"),
        ("", ""),
        ("", "  \n ")
    ])
    func textThatSavesAsTheSameNoteLeavesModelUnchanged(note: String, text: String) throws {
        let item = makeItem(note: note)
        try context.save()
        try #require(!context.hasChanges)

        item.updateNote(to: text)

        #expect(item.note == note)
        #expect(!item.hasChanges)
        #expect(!context.hasChanges)
    }
}

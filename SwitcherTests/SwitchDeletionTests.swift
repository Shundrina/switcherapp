import Foundation
import SwiftData
import Testing
@testable import Switcher

/// Тексти підтвердження, яке з'являється після свайпу по картці у списку.
@MainActor
struct SwitchDeletionConfirmationTests {
    @Test(arguments: [
        ("Полила квіти", "Видалити «Полила квіти»?"),
        ("Газ горить", "Видалити «Газ горить»?")
    ])
    func titleQuotesSwitchName(name: String, expected: String) {
        #expect(SwitchDeletion.confirmationTitle(for: name) == expected)
    }

    // `AddSwitchView` не дає зберегти порожню назву, але в моделі вона має значення
    // за замовчуванням "" — заголовок не повинен показувати порожні лапки «».
    @Test(arguments: ["", "   ", "\n"])
    func titleForBlankNameHasNoEmptyQuotes(name: String) {
        #expect(SwitchDeletion.confirmationTitle(for: name) == "Видалити перемикач?")
    }

    // Формулювання вільне; перевіряється суть: історію теж буде видалено, і дію не можна скасувати.
    @Test func messageWarnsAboutHistoryAndIrreversibility() {
        let message = SwitchDeletion.confirmationMessage.lowercased()

        #expect(message.contains("істор"), "Немає згадки про історію: «\(message)»")
        #expect(
            message.contains("не можна скасувати") || message.contains("неможливо скасувати"),
            "Не сказано, що дію не можна скасувати: «\(message)»"
        )
    }

    @Test func buttonTitles() {
        #expect(SwitchDeletion.confirmButtonTitle == "Видалити")
        #expect(SwitchDeletion.cancelButtonTitle == "Скасувати")
    }
}

/// Операція, яку виконує кнопка «Видалити» в підтвердженні.
@MainActor
struct SwitchDeletionTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    /// Перемикач, який по черзі вмикали й вимикали у вказані моменти (перший — увімкнення).
    private func makeItem(name: String, toggledAt dates: [Date]) -> SwitchItem {
        let item = SwitchItem(name: name)
        context.insert(item)
        for (index, date) in dates.enumerated() {
            item.setOn(index.isMultiple(of: 2), at: date)
        }
        return item
    }

    private func items(in context: ModelContext) throws -> [SwitchItem] {
        try context.fetch(FetchDescriptor<SwitchItem>())
    }

    /// Усі події, від найдавнішої.
    private func events(in context: ModelContext) throws -> [SwitchEvent] {
        try context.fetch(FetchDescriptor<SwitchEvent>(sortBy: [SortDescriptor(\.timestamp)]))
    }

    /// Те, що опиниться у сховищі після автозбереження: зберігає контекст і читає новим.
    private func savedStore() throws -> ModelContext {
        try context.save()
        return ModelContext(container)
    }

    // Вимоги 2 і 4: видаленого перемикача й жодної його події немає,
    // а інший перемикач, його стан і його історія лишилися як були.
    @Test func deleteRemovesSwitchWithItsHistoryAndLeavesOthersUntouched() throws {
        let doomed = makeItem(name: "Полила квіти", toggledAt: [
            TestClock.date(day: 9, hour: 8, minute: 15),
            TestClock.date(day: 9, hour: 21, minute: 30)
        ])
        let keptDates = [
            TestClock.date(day: 8, hour: 7, minute: 0),
            TestClock.date(day: 9, hour: 12, minute: 45),
            TestClock.date(day: 10, hour: 23, minute: 59)
        ]
        let kept = makeItem(name: "Газ горить", toggledAt: keptDates)
        try context.save()
        try #require(try events(in: context).count == 5)

        SwitchDeletion.delete(doomed, from: context)

        // Одразу після операції, без явного збереження.
        #expect(try items(in: context).map(\.persistentModelID) == [kept.persistentModelID])
        let remaining = try events(in: context)
        #expect(remaining.map(\.timestamp) == keptDates)
        #expect(remaining.map(\.isOn) == [true, false, true])
        #expect(remaining.allSatisfy { $0.item?.persistentModelID == kept.persistentModelID })
        #expect(kept.name == "Газ горить")
        #expect(kept.isOn)
        #expect(kept.lastToggledAt == keptDates[2])
        #expect(kept.sortedEvents.map(\.timestamp) == Array(keptDates.reversed()))

        // І у сховищі після збереження.
        let store = try savedStore()
        #expect(try items(in: store).map(\.name) == ["Газ горить"])
        #expect(try events(in: store).map(\.timestamp) == keptDates)
    }

    // Назви не унікальні (модель сумісна з CloudKit): видаляється саме вказаний перемикач,
    // а не всі з такою назвою.
    @Test func deleteRemovesOnlyTheGivenSwitchAmongNamesakes() throws {
        let doomedDate = TestClock.date(day: 9, hour: 8, minute: 15)
        let keptDate = TestClock.date(day: 10, hour: 9, minute: 40)
        let doomed = makeItem(name: "Двері зачинені", toggledAt: [doomedDate])
        let kept = makeItem(name: "Двері зачинені", toggledAt: [keptDate])
        try context.save()

        SwitchDeletion.delete(doomed, from: context)

        #expect(try items(in: context).map(\.persistentModelID) == [kept.persistentModelID])
        #expect(try events(in: context).map(\.timestamp) == [keptDate])
    }

    // Сценарій «створила помилково»: перемикач щойно додано й перемкнуто, автозбереження
    // ще не спрацювало. Після видалення у сховище не має потрапити ні він, ні його події.
    @Test func deleteRemovesSwitchThatWasNeverSaved() throws {
        let item = makeItem(name: "Полила квіти", toggledAt: [
            TestClock.date(day: 11, hour: 13, minute: 58),
            TestClock.date(day: 11, hour: 13, minute: 59)
        ])

        SwitchDeletion.delete(item, from: context)

        #expect(try items(in: context).isEmpty)
        #expect(try events(in: context).isEmpty)
        let store = try savedStore()
        #expect(try items(in: store).isEmpty)
        #expect(try events(in: store).isEmpty)
    }
}

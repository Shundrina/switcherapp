import Foundation
import SwiftData
import Testing
@testable import Switcher

// Стабільний ідентифікатор перемикача — `SwitchItem.uuid`. Він потрапляє в `userInfo` сповіщення,
// щоб дія «Перемкнути» знайшла перемикач. Поле має значення за замовчуванням (CloudKit-сумісність),
// а легка міграція SwiftData може дати всім наявним записам ОДНЕ значення за замовчуванням —
// тому є `SwitchIdentity`, яка лагодить дублікати: перший власник UUID його зберігає, решта
// отримують нові; унікальні UUID не змінюються.

/// UUID із фіксованим числом у кінці — детерміновані входи для тестів.
private func fixedUUID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
}

@MainActor
struct SwitchUUIDTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    @Test func newSwitchesGetDistinctUUIDs() {
        let flowers = SwitchItem(name: "Полила квіти")
        let gas = SwitchItem(name: "Газ горить")
        context.insert(flowers)
        context.insert(gas)

        #expect(flowers.uuid != gas.uuid)
    }

    @Test func uuidDoesNotChangeWhenSwitchIsToggledRenamedOrSaved() throws {
        let item = SwitchItem(name: "Газ горить")
        context.insert(item)
        let original = item.uuid

        item.setOn(true, at: TestClock.date(day: 11, hour: 8, minute: 0))
        item.rename(to: "Плита")
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<SwitchItem>()).first)
        #expect(fetched.uuid == original)
    }
}

/// Чиста функція над значеннями: порядок і кількість зберігаються.
@MainActor
struct SwitchIdentityRepairTests {
    @Test func uniqueUUIDsAreLeftUntouched() {
        let ids = [fixedUUID(1), fixedUUID(2), fixedUUID(3)]

        #expect(SwitchIdentity.repairingDuplicates(ids) == ids)
    }

    @Test func emptyInputGivesEmptyOutput() {
        #expect(SwitchIdentity.repairingDuplicates([]).isEmpty)
    }

    // Сценарій легкої міграції: усі наявні записи отримали одне значення за замовчуванням.
    @Test func allSameUUIDKeepsFirstAndRenewsTheRest() throws {
        let shared = fixedUUID(7)

        let repaired = SwitchIdentity.repairingDuplicates([shared, shared, shared])

        try #require(repaired.count == 3)
        #expect(repaired[0] == shared)
        #expect(Set(repaired).count == 3, "Після лагодження UUID мають бути різними: \(repaired)")
    }

    @Test func onlyRepeatedOccurrencesAfterTheFirstAreRenewed() throws {
        let a = fixedUUID(1), b = fixedUUID(2), c = fixedUUID(3)

        let repaired = SwitchIdentity.repairingDuplicates([a, b, a, c, a, b])

        try #require(repaired.count == 6)
        // Перші входження й унікальні — на своїх місцях.
        #expect(repaired[0] == a)
        #expect(repaired[1] == b)
        #expect(repaired[3] == c)
        // Повтори отримали нові UUID, яких не було у вхідних даних, і всі вони різні.
        for index in [2, 4, 5] {
            #expect(![a, b, c].contains(repaired[index]), "Повтор на позиції \(index) не замінено")
        }
        #expect(Set(repaired).count == 6, "Після лагодження UUID мають бути різними: \(repaired)")
    }
}

/// Те саме лагодження, застосоване до перемикачів у сховищі (так його викликає застосунок при запуску).
@MainActor
struct SwitchIdentityRepairItemsTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(_ name: String, uuid: UUID) -> SwitchItem {
        let item = SwitchItem(name: name)
        item.uuid = uuid
        context.insert(item)
        return item
    }

    @Test func duplicatedSwitchesGetNewUUIDsExceptTheFirst() {
        let shared = fixedUUID(9)
        let unique = fixedUUID(10)
        let first = makeItem("Полила квіти", uuid: shared)
        let second = makeItem("Газ горить", uuid: shared)
        let alone = makeItem("Двері зачинені", uuid: unique)
        let third = makeItem("Ліки", uuid: shared)

        SwitchIdentity.repairDuplicates(in: [first, second, alone, third])

        #expect(first.uuid == shared)
        #expect(alone.uuid == unique)
        #expect(second.uuid != shared)
        #expect(third.uuid != shared)
        #expect(Set([first, second, alone, third].map(\.uuid)).count == 4)
    }

    @Test func switchesWithUniqueUUIDsAreUnchanged() {
        let items = [makeItem("Полила квіти", uuid: fixedUUID(1)), makeItem("Газ горить", uuid: fixedUUID(2))]

        SwitchIdentity.repairDuplicates(in: items)

        #expect(items.map(\.uuid) == [fixedUUID(1), fixedUUID(2)])
    }
}

import Foundation
import SwiftData
import Testing
@testable import Switcher

// Правило нагадування — `ReminderRule` (@Model, CloudKit-сумісне). Тип, умова й одиниця
// зберігаються сирими рядками (`kindRaw`, `conditionRaw`, `unitRaw`), як значок і колір перемикача,
// тож етап 2 додасть тип «у певний час» без міграції.
//
// Невідоме сире значення читається так само, як значення за замовчуванням у моделі:
// тип — «через певний час», умова — «завжди», одиниця — години. Чому «завжди»: це надмножина
// «увімкнено»/«вимкнено», тож нагадування не загубиться мовчки — у гіршому разі прийде зайве,
// і користувачка побачить і виправить правило. Години — середня одиниця: не засипає сповіщеннями
// щохвилини й не відкладає нагадування на дні.

@MainActor
struct ReminderRuleValueTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    @Test func newRuleStoresItsFields() {
        let rule = ReminderRule(condition: .off, amount: 45, unit: .hours, repeats: false)
        context.insert(rule)

        #expect(rule.kind == .afterDuration)
        #expect(rule.condition == .off)
        #expect(rule.amount == 45)
        #expect(rule.unit == .hours)
        #expect(rule.repeats == false)
    }

    @Test func rawValuesAreStableStrings() {
        let rule = ReminderRule(condition: .off, amount: 2, unit: .hours)
        context.insert(rule)
        #expect(rule.kindRaw == "afterDuration")
        #expect(rule.conditionRaw == "off")
        #expect(rule.unitRaw == "hours")

        rule.condition = .always
        rule.unit = .days
        #expect(rule.conditionRaw == "always")
        #expect(rule.unitRaw == "days")

        rule.condition = .on
        rule.unit = .minutes
        #expect(rule.conditionRaw == "on")
        #expect(rule.unitRaw == "minutes")
    }

    @Test func newRulesGetDistinctUUIDs() {
        let first = ReminderRule(condition: .on, amount: 30, unit: .minutes)
        let second = ReminderRule(condition: .on, amount: 30, unit: .minutes)
        context.insert(first)
        context.insert(second)

        #expect(first.uuid != second.uuid)
    }

    @Test func unknownStoredValuesFallBackToDefaults() {
        let rule = ReminderRule(condition: .on, amount: 30, unit: .minutes)
        context.insert(rule)

        rule.kindRaw = "atTimeOfDay"
        rule.conditionRaw = "sometimes"
        rule.unitRaw = "weeks"

        #expect(rule.kind == .afterDuration)
        #expect(rule.condition == .always)
        #expect(rule.unit == .hours)
    }

    // Повтор за замовчуванням: увімкнено для хвилин і годин, вимкнено для днів.
    @Test(arguments: [
        (ReminderUnit.minutes, true),
        (ReminderUnit.hours, true),
        (ReminderUnit.days, false)
    ])
    func repeatsByDefaultDependsOnUnit(unit: ReminderUnit, expected: Bool) {
        #expect(unit.repeatsByDefault == expected)

        let rule = ReminderRule(condition: .always, amount: 3, unit: unit)
        context.insert(rule)
        #expect(rule.repeats == expected)
    }

    @Test func explicitRepeatsOverridesDefault() {
        let daily = ReminderRule(condition: .always, amount: 3, unit: .days, repeats: true)
        let minutes = ReminderRule(condition: .on, amount: 30, unit: .minutes, repeats: false)
        context.insert(daily)
        context.insert(minutes)

        #expect(daily.repeats == true)
        #expect(minutes.repeats == false)
    }
}

/// Зв'язок «перемикач — правила»: необов'язковий, каскадне видалення.
@MainActor
struct ReminderRuleRelationshipTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        // Лише `SwitchItem.self`, як у застосунку: `ReminderRule` має потрапити в схему через зв'язок.
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(_ name: String = "Газ горить") -> SwitchItem {
        let item = SwitchItem(name: name)
        context.insert(item)
        return item
    }

    @discardableResult
    private func addRule(to item: SwitchItem, _ condition: ReminderCondition = .on, amount: Int = 30,
                         unit: ReminderUnit = .minutes) -> ReminderRule {
        let rule = ReminderRule(condition: condition, amount: amount, unit: unit)
        context.insert(rule)
        rule.item = item
        return rule
    }

    @Test func newSwitchHasNoRules() {
        #expect((makeItem().rules ?? []).isEmpty)
    }

    @Test func ruleAttachedToSwitchAppearsInItsRules() throws {
        let item = makeItem()
        let rule = addRule(to: item)
        try context.save()

        #expect(item.rules?.count == 1)
        #expect(item.rules?.first?.uuid == rule.uuid)
    }

    @Test func deletingSwitchDeletesItsRules() throws {
        let gas = makeItem("Газ горить")
        let flowers = makeItem("Полила квіти")
        addRule(to: gas, .on, amount: 30, unit: .minutes)
        addRule(to: gas, .always, amount: 2, unit: .hours)
        addRule(to: flowers, .always, amount: 3, unit: .days)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<ReminderRule>()) == 3)

        SwitchDeletion.delete(gas, from: context)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<ReminderRule>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.item?.name == "Полила квіти")
    }

    @Test func deletingRuleKeepsSwitchAndOtherRules() throws {
        let item = makeItem()
        let first = addRule(to: item, .on, amount: 30, unit: .minutes)
        let second = addRule(to: item, .off, amount: 2, unit: .hours)
        try context.save()

        context.delete(first)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SwitchItem>()) == 1)
        #expect(item.rules?.map(\.uuid) == [second.uuid])
    }
}

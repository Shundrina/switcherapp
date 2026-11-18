import Foundation
import SwiftData
import Testing
@testable import Switcher

// Розділ «Нагадування» на екрані перемикача і вікно правила: текст рядка правила, приклад сповіщення
// у вікні правила й чернетка правила (`ReminderRuleDraft`), яку редагує вікно.

/// Текст рядка правила: «Через 30 хв, коли увімкнено», «Через 2 год, коли вимкнено»,
/// «Через 3 дні без перемикань»; з повтором — « · повтор».
@MainActor
struct ReminderRuleSummaryTests {
    @Test(arguments: [
        (ReminderCondition.on, 30, ReminderUnit.minutes, "Через 30 хв, коли увімкнено"),
        (ReminderCondition.off, 2, ReminderUnit.hours, "Через 2 год, коли вимкнено"),
        (ReminderCondition.always, 3, ReminderUnit.days, "Через 3 дні без перемикань"),
        (ReminderCondition.on, 1, ReminderUnit.minutes, "Через 1 хв, коли увімкнено"),
        (ReminderCondition.on, 59, ReminderUnit.minutes, "Через 59 хв, коли увімкнено"),
        (ReminderCondition.off, 1, ReminderUnit.hours, "Через 1 год, коли вимкнено"),
        (ReminderCondition.off, 24, ReminderUnit.hours, "Через 24 год, коли вимкнено"),
        (ReminderCondition.on, 2, ReminderUnit.days, "Через 2 дні, коли увімкнено"),
        (ReminderCondition.off, 5, ReminderUnit.days, "Через 5 днів, коли вимкнено"),
        // Число — як введено: хвилини понад 60 у години не переносяться (на відміну від тексту сповіщення).
        (ReminderCondition.on, 90, ReminderUnit.minutes, "Через 90 хв, коли увімкнено"),
        (ReminderCondition.off, 120, ReminderUnit.minutes, "Через 120 хв, коли вимкнено")
    ])
    func summaryWithoutRepeat(condition: ReminderCondition, amount: Int, unit: ReminderUnit, expected: String) {
        #expect(ReminderFormatting.ruleSummary(condition: condition, amount: amount, unit: unit, repeats: false) == expected)
    }

    @Test(arguments: [
        (ReminderCondition.on, 30, ReminderUnit.minutes, "Через 30 хв, коли увімкнено · повтор"),
        (ReminderCondition.off, 2, ReminderUnit.hours, "Через 2 год, коли вимкнено · повтор"),
        (ReminderCondition.always, 3, ReminderUnit.days, "Через 3 дні без перемикань · повтор"),
        (ReminderCondition.always, 150, ReminderUnit.minutes, "Через 150 хв без перемикань · повтор")
    ])
    func summaryWithRepeat(condition: ReminderCondition, amount: Int, unit: ReminderUnit, expected: String) {
        #expect(ReminderFormatting.ruleSummary(condition: condition, amount: amount, unit: unit, repeats: true) == expected)
    }

    @Test(arguments: [
        (1, "1 день"), (2, "2 дні"), (4, "4 дні"), (5, "5 днів"), (11, "11 днів"), (12, "12 днів"),
        (14, "14 днів"), (21, "21 день"), (22, "22 дні"), (25, "25 днів"), (111, "111 днів"), (101, "101 день")
    ])
    func summaryUsesUkrainianDayForms(days: Int, expected: String) {
        #expect(ReminderFormatting.ruleSummary(condition: .always, amount: days, unit: .days, repeats: false)
            == "Через \(expected) без перемикань")
    }
}

/// Приклад сповіщення внизу вікна правила: текст першого нагадування для поточних значень —
/// той самий, що згенерує планувальник.
@MainActor
struct ReminderPreviewBodyTests {
    @Test(arguments: [
        (ReminderCondition.on, 30, ReminderUnit.minutes, "Увімкнено вже 30 хв"),
        (ReminderCondition.off, 2, ReminderUnit.hours, "Вимкнено вже 2 год"),
        (ReminderCondition.always, 3, ReminderUnit.days, "Не перемикали вже 3 дні"),
        (ReminderCondition.on, 90, ReminderUnit.minutes, "Увімкнено вже 1 год 30 хв"),
        (ReminderCondition.always, 1, ReminderUnit.days, "Не перемикали вже 1 день")
    ])
    func previewBodyMatchesFirstReminder(condition: ReminderCondition, amount: Int, unit: ReminderUnit, expected: String) {
        #expect(ReminderFormatting.previewBody(condition: condition, amount: amount, unit: unit) == expected)
    }

    @Test func previewTitleIsIconAndName() {
        #expect(ReminderFormatting.title(icon: SwitchIcon(rawValue: "🔥")!, name: "Газ горить") == "🔥 Газ горить")
    }
}

/// Одна зміна в чернетці правила.
enum DraftChange: CaseIterable, Sendable { case condition, amount, unit, repeats }

/// Чернетка правила у вікні: значення нового правила, скидання повтору при зміні одиниці,
/// межі числа (1…999) і збереження в `ReminderRule` з оновленням `editedAt` лише при зміні.
@MainActor
struct ReminderRuleDraftTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let createdAt = TestClock.date(day: 1, hour: 9, minute: 0)
    let savedAt = TestClock.date(day: 11, hour: 14, minute: 0)

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeRule() -> ReminderRule {
        let rule = ReminderRule(condition: .off, amount: 2, unit: .hours, repeats: false, editedAt: createdAt)
        context.insert(rule)
        return rule
    }

    @Test func newRuleDefaultsToOnThirtyMinutesWithRepeat() {
        let draft = ReminderRuleDraft()

        #expect(draft.condition == .on)
        #expect(draft.amount == 30)
        #expect(draft.unit == .minutes)
        #expect(draft.repeats == true)
        #expect(draft.canSave)
    }

    @Test func draftOfExistingRuleHasItsValues() {
        let draft = ReminderRuleDraft(rule: makeRule())

        #expect(draft.condition == .off)
        #expect(draft.amount == 2)
        #expect(draft.unit == .hours)
        #expect(draft.repeats == false)
    }

    // Зміна одиниці скидає повтор на типовий для неї — навіть якщо його перед тим змінили вручну.
    @Test func changingUnitResetsRepeatToItsDefault() {
        var draft = ReminderRuleDraft()

        draft.unit = .days
        #expect(draft.repeats == false)

        draft.unit = .hours
        #expect(draft.repeats == true)

        draft.repeats = false
        draft.unit = .minutes
        #expect(draft.repeats == true)

        draft.repeats = true
        draft.unit = .days
        #expect(draft.repeats == false)
    }

    // Відкрили наявне правило — його повтор не скидається, поки одиницю не змінили.
    @Test func openingExistingRuleKeepsItsRepeat() {
        let rule = ReminderRule(condition: .always, amount: 3, unit: .days, repeats: true, editedAt: createdAt)
        context.insert(rule)

        let draft = ReminderRuleDraft(rule: rule)

        #expect(draft.repeats == true)
    }

    @Test(arguments: [(0, false), (1, true), (30, true), (999, true), (1000, false), (-1, false)])
    func amountMustBeFromOneTo999(amount: Int, canSave: Bool) {
        var draft = ReminderRuleDraft()
        draft.amount = amount

        #expect(draft.canSave == canSave)
    }

    @Test func makeRuleCreatesRuleEditedAtSaveTime() {
        var draft = ReminderRuleDraft()
        draft.condition = .always
        draft.unit = .days
        draft.amount = 3

        let rule = draft.makeRule(at: savedAt)
        context.insert(rule)

        #expect(rule.condition == .always)
        #expect(rule.amount == 3)
        #expect(rule.unit == .days)
        #expect(rule.repeats == false)
        #expect(rule.editedAt == savedAt)
    }

    @Test func applyingChangedDraftUpdatesRuleAndEditedAt() {
        let rule = makeRule()
        var draft = ReminderRuleDraft(rule: rule)
        draft.condition = .on
        draft.amount = 45
        draft.unit = .minutes
        draft.repeats = false

        draft.apply(to: rule, at: savedAt)

        #expect(rule.condition == .on)
        #expect(rule.amount == 45)
        #expect(rule.unit == .minutes)
        #expect(rule.repeats == false)
        #expect(rule.editedAt == savedAt)
    }

    // «Зберегти» без змін — це не зміна правила: `editedAt` лишається, тож запізніле нагадування
    // не повториться ще раз.
    @Test func applyingUnchangedDraftKeepsEditedAt() {
        let rule = makeRule()
        let draft = ReminderRuleDraft(rule: rule)

        draft.apply(to: rule, at: savedAt)

        #expect(rule.editedAt == createdAt)
        #expect(rule.condition == .off)
        #expect(rule.amount == 2)
    }

    @Test(arguments: DraftChange.allCases)
    func anySingleChangeUpdatesEditedAt(change: DraftChange) {
        let rule = makeRule()
        var draft = ReminderRuleDraft(rule: rule)
        switch change {
        case .condition: draft.condition = .always
        case .amount: draft.amount = 3
        case .unit: draft.unit = .days
        case .repeats: draft.repeats = true
        }

        draft.apply(to: rule, at: savedAt)

        #expect(rule.editedAt == savedAt)
    }
}

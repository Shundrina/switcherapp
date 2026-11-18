import Foundation
import SwiftData
import Testing
@testable import Switcher

// «Запізніле правило»: правило створили чи змінили, коли його перше нагадування вже мало б минути.
// Тоді нагадати через 1 хв після створення/зміни правила (`editedAt + 60 с`), повтори — +10/+20 хв
// від цього; текст — фактичний прожитий час на той момент. Точка відліку — момент зміни правила,
// а не `now`: при кожному відкритті застосунку нагадування не повторюється.
// Якщо й ці дати минули — нічого. Якщо перше нагадування ще попереду — без змін.

private func fixedUUID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
}

private func kyiv(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int = 0) -> Date {
    TestClock.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute, second: second))!
}

@MainActor
struct ReminderLateRuleTests {
    let calendar = TestClock.calendar
    let switchID = fixedUUID(100)
    static let flame = SwitchIcon(rawValue: "🔥")!

    private func snapshot(isOn: Bool, lastToggledAt: Date, _ rule: ReminderRuleSnapshot) -> ReminderSwitchSnapshot {
        ReminderSwitchSnapshot(
            id: switchID, name: "Газ горить", icon: Self.flame, isOn: isOn,
            createdAt: kyiv(1, 1, 9, 0), lastToggledAt: lastToggledAt, rules: [rule]
        )
    }

    private func rule(_ condition: ReminderCondition, _ amount: Int, _ unit: ReminderUnit, repeats: Bool,
                      editedAt: Date) -> ReminderRuleSnapshot {
        ReminderRuleSnapshot(id: fixedUUID(1), condition: condition, amount: amount, unit: unit, repeats: repeats,
                             editedAt: editedAt)
    }

    private func plan(_ item: ReminderSwitchSnapshot, now: Date) -> [PlannedReminder] {
        ReminderPlanner.plan(for: [item], now: now, calendar: calendar).sorted { $0.date < $1.date }
    }

    // MARK: - Нагадування через 1 хв після зміни правила

    // Квіти не поливали з 1 листопада; правило «3 дні» додали 6 листопада о 12:00 — термін минув 4-го.
    @Test func lateDaysRuleRemindsMinuteAfterEditWithActualDays() {
        let edited = kyiv(11, 6, 12, 0)
        let item = snapshot(isOn: false, lastToggledAt: kyiv(11, 1, 10, 0), rule(.always, 3, .days, repeats: false, editedAt: edited))

        let result = plan(item, now: edited)

        #expect(result.map(\.date) == [kyiv(11, 6, 12, 1)])
        #expect(result.map(\.body) == ["Не перемикали вже 5 днів"])
        #expect(result.map(\.title) == ["🔥 Газ горить"])
        #expect(result.map(\.payload) == [ReminderPayload(switchID: switchID, wasOn: false)])
    }

    // Газ увімкнули о 08:00; правило «1 год, з повтором» додали о 10:00.
    @Test func lateHoursRuleRepeatsFromMinuteAfterEdit() {
        let edited = kyiv(11, 11, 10, 0)
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 1, .hours, repeats: true, editedAt: edited))

        let result = plan(item, now: edited)

        #expect(result.map(\.date) == [kyiv(11, 11, 10, 1), kyiv(11, 11, 10, 11), kyiv(11, 11, 10, 21)])
        #expect(result.map(\.body) == [
            "Увімкнено вже 2 год 1 хв", "Увімкнено вже 2 год 11 хв", "Увімкнено вже 2 год 21 хв"
        ])
    }

    @Test func lateMinutesRuleShowsActualElapsedTime() {
        let edited = kyiv(11, 11, 8, 45)
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 30, .minutes, repeats: true, editedAt: edited))

        let result = plan(item, now: edited)

        #expect(result.map(\.date) == [kyiv(11, 11, 8, 46), kyiv(11, 11, 8, 56), kyiv(11, 11, 9, 6)])
        #expect(result.map(\.body) == ["Увімкнено вже 46 хв", "Увімкнено вже 56 хв", "Увімкнено вже 1 год 6 хв"])
    }

    // Прожиті дні — календарні: 28.03 10:00 → 30.03 10:01 у Києві — це 2 дні, хоч минуло лише 47 год.
    @Test func lateDaysCountCalendarDaysAcrossSpringForward() {
        let edited = kyiv(3, 30, 10, 0)
        let item = snapshot(isOn: false, lastToggledAt: kyiv(3, 28, 10, 0), rule(.always, 1, .days, repeats: false, editedAt: edited))

        let result = plan(item, now: edited)

        #expect(result.map(\.date) == [kyiv(3, 30, 10, 1)])
        #expect(result.map(\.body) == ["Не перемикали вже 2 дні"])
    }

    // Межа: перше нагадування припадає рівно на момент зміни — воно вже «минуло».
    @Test func reminderDueExactlyAtEditIsLate() {
        let edited = kyiv(11, 11, 8, 30)
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 30, .minutes, repeats: false, editedAt: edited))

        let result = plan(item, now: edited)

        #expect(result.map(\.date) == [kyiv(11, 11, 8, 31)])
        #expect(result.map(\.body) == ["Увімкнено вже 31 хв"])
    }

    // MARK: - Без змін

    // Перше нагадування ще попереду (на хвилину пізніше за зміну правила) — звичайний план.
    @Test func ruleDueAfterEditIsPlannedAsUsual() {
        let edited = kyiv(11, 11, 8, 29)
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 30, .minutes, repeats: true, editedAt: edited))

        let result = plan(item, now: edited)

        #expect(result.map(\.date) == [kyiv(11, 11, 8, 30), kyiv(11, 11, 8, 40), kyiv(11, 11, 8, 50)])
        #expect(result.map(\.body) == ["Увімкнено вже 30 хв", "Увімкнено вже 40 хв", "Увімкнено вже 50 хв"])
    }

    // Перемкнули вже після зміни правила — відлік звичайний, від перемикання.
    @Test func toggleAfterEditCountsFromToggle() {
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 9, 0),
                            rule(.on, 30, .minutes, repeats: false, editedAt: kyiv(11, 11, 8, 0)))

        let result = plan(item, now: kyiv(11, 11, 9, 5))

        #expect(result.map(\.date) == [kyiv(11, 11, 9, 30)])
        #expect(result.map(\.body) == ["Увімкнено вже 30 хв"])
    }

    @Test func lateRuleStillRespectsCondition() {
        let edited = kyiv(11, 11, 10, 0)
        let item = snapshot(isOn: false, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 1, .hours, repeats: true, editedAt: edited))

        #expect(plan(item, now: edited).isEmpty)
    }

    // MARK: - Без спаму при наступних відкриттях

    // Застосунок відкрили наступного дня — запізніле нагадування вже минуло, нового немає.
    @Test func lateReminderIsNotRepeatedOnLaterLaunch() {
        let edited = kyiv(11, 6, 12, 0)
        let item = snapshot(isOn: false, lastToggledAt: kyiv(11, 1, 10, 0), rule(.always, 3, .days, repeats: true, editedAt: edited))

        #expect(plan(item, now: kyiv(11, 7, 9, 0)).isEmpty)
    }

    // Відкрили через 15 хв після зміни правила — лишається тільки третє (editedAt + 21 хв).
    @Test func lateRepeatsInThePastAreSkipped() {
        let edited = kyiv(11, 11, 10, 0)
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 1, .hours, repeats: true, editedAt: edited))

        let result = plan(item, now: kyiv(11, 11, 10, 15))

        #expect(result.map(\.date) == [kyiv(11, 11, 10, 21)])
        #expect(result.map(\.body) == ["Увімкнено вже 2 год 21 хв"])
    }

    // Те саме правило, той самий момент зміни — id ті самі, що й у звичайного плану (0, 1, 2).
    @Test func lateRemindersKeepDeterministicIdentifiers() {
        let edited = kyiv(11, 11, 10, 0)
        let item = snapshot(isOn: true, lastToggledAt: kyiv(11, 11, 8, 0), rule(.on, 1, .hours, repeats: true, editedAt: edited))

        let early = plan(item, now: edited)
        let later = plan(item, now: kyiv(11, 11, 10, 5))

        #expect(early.count == 3)
        #expect(Set(early.map(\.id)).count == 3)
        #expect(later.map(\.id) == Array(early.map(\.id).dropFirst()))
    }
}

/// `ReminderRule.editedAt` і знімок правила.
@MainActor
struct ReminderRuleEditedAtTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    @Test func newRuleIsEditedNowByDefault() {
        let before = Date.now
        let rule = ReminderRule(condition: .on, amount: 30, unit: .minutes)
        context.insert(rule)
        let after = Date.now

        #expect(rule.editedAt >= before && rule.editedAt <= after)
    }

    @Test func explicitEditedAtIsStored() {
        let date = TestClock.date(day: 6, hour: 12, minute: 0)
        let rule = ReminderRule(condition: .always, amount: 3, unit: .days, repeats: false, editedAt: date)
        context.insert(rule)

        #expect(rule.editedAt == date)
    }

    @Test func snapshotCarriesEditedAt() throws {
        let item = SwitchItem(name: "Полила квіти")
        context.insert(item)
        let date = TestClock.date(day: 6, hour: 12, minute: 0)
        let rule = ReminderRule(condition: .always, amount: 3, unit: .days, repeats: false, editedAt: date)
        context.insert(rule)
        rule.item = item

        let snapshot = ReminderSwitchSnapshot(item)

        #expect(snapshot.rules.map(\.editedAt) == [date])
    }
}

import Foundation
import Testing
@testable import Switcher

// Планувальник — чиста `nonisolated` функція `ReminderPlanner.plan(for:now:calendar:)`:
// знімки перемикачів і правил (прості значення) + `now` + `Calendar` → заплановані сповіщення.
//
// - Відлік — від `lastToggledAt ?? createdAt`.
// - Умова: `on` — лише коли перемикач увімкнено, `off` — лише коли вимкнено, `always` — завжди.
// - Перше сповіщення — відлік + тривалість: хвилини й години — абсолютні секунди, дні — календарні
//   (та сама година на годиннику навіть через перехід на літній/зимовий час).
// - Повтор: ще 2 сповіщення через 10 і 20 хв після першого. Дати ≤ now пропускаються.
// - Більше 64 — лишаються 64 найраніші. Порядок результату не задано: тести сортують самі.

/// Мить за київським годинником (для березня й жовтня 2026 — навколо переведення годинника).
private func kyiv(_ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    TestClock.calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
}

private func fixedUUID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
}

@MainActor
struct ReminderPlannerTests {
    let calendar = TestClock.calendar
    let gasID = fixedUUID(100)
    let flowersID = fixedUUID(200)
    /// Останнє перемикання газу: 11 листопада, 08:00 за Києвом.
    let toggledAt = TestClock.date(day: 11, hour: 8, minute: 0)
    let createdAt = TestClock.date(day: 1, hour: 9, minute: 0)

    static let flame = SwitchIcon(rawValue: "🔥")!
    static let plant = SwitchIcon(rawValue: "🪴")!

    /// Правило, змінене давно (`editedAt` — `.distantPast`): «запізніле правило» тут не діє,
    /// його перевіряє `ReminderLateRuleTests`.
    private func rule(_ condition: ReminderCondition, _ amount: Int, _ unit: ReminderUnit,
                      repeats: Bool = false, id: UUID = fixedUUID(1)) -> ReminderRuleSnapshot {
        ReminderRuleSnapshot(id: id, condition: condition, amount: amount, unit: unit, repeats: repeats,
                             editedAt: .distantPast)
    }

    /// Газ. `lastToggledAt`: не передано — `toggledAt`; `.some(nil)` — ще не перемикали.
    private func gas(isOn: Bool = true, lastToggledAt: Date?? = .none, id: UUID? = nil,
                     _ rules: [ReminderRuleSnapshot]) -> ReminderSwitchSnapshot {
        let lastToggle: Date? = switch lastToggledAt {
        case .none: toggledAt
        case .some(let date): date
        }
        return ReminderSwitchSnapshot(
            id: id ?? gasID, name: "Газ горить", icon: Self.flame, isOn: isOn,
            createdAt: createdAt, lastToggledAt: lastToggle, rules: rules
        )
    }

    private func flowers(isOn: Bool = true, lastToggledAt: Date, _ rules: [ReminderRuleSnapshot]) -> ReminderSwitchSnapshot {
        ReminderSwitchSnapshot(
            id: flowersID, name: "Полила квіти", icon: Self.plant, isOn: isOn,
            createdAt: createdAt, lastToggledAt: lastToggledAt, rules: rules
        )
    }

    /// План, відсортований за датою.
    private func plan(_ switches: [ReminderSwitchSnapshot], now: Date, calendar: Calendar? = nil) -> [PlannedReminder] {
        ReminderPlanner.plan(for: switches, now: now, calendar: calendar ?? self.calendar)
            .sorted { $0.date < $1.date }
    }

    // MARK: - Перше сповіщення, заголовок, текст, userInfo

    @Test func onRuleFiresAfterMinutesSinceLastToggle() throws {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        let result = plan([gas(isOn: true, [rule(.on, 30, .minutes)])], now: now)

        try #require(result.count == 1)
        let reminder = result[0]
        #expect(reminder.date == toggledAt.addingTimeInterval(30 * 60))
        #expect(reminder.title == "🔥 Газ горить")
        #expect(reminder.body == "Увімкнено вже 30 хв")
        #expect(reminder.payload == ReminderPayload(switchID: gasID, wasOn: true))
    }

    @Test func countdownStartsAtCreationWhenNeverToggled() throws {
        let now = TestClock.date(day: 1, hour: 9, minute: 30)
        let neverToggled = gas(isOn: false, lastToggledAt: .some(nil), [rule(.off, 2, .hours)])

        let result = plan([neverToggled], now: now)

        try #require(result.count == 1)
        #expect(result[0].date == createdAt.addingTimeInterval(2 * 3600))
        #expect(result[0].body == "Вимкнено вже 2 год")
        #expect(result[0].payload == ReminderPayload(switchID: gasID, wasOn: false))
    }

    @Test(arguments: [
        (ReminderCondition.on, true, 1),
        (ReminderCondition.on, false, 0),
        (ReminderCondition.off, true, 0),
        (ReminderCondition.off, false, 1),
        (ReminderCondition.always, true, 1),
        (ReminderCondition.always, false, 1)
    ])
    func conditionDecidesWhetherRuleApplies(condition: ReminderCondition, isOn: Bool, expectedCount: Int) {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        let result = plan([gas(isOn: isOn, [rule(condition, 30, .minutes)])], now: now)

        #expect(result.count == expectedCount)
    }

    @Test(arguments: [true, false])
    func alwaysRuleSaysNotToggled(isOn: Bool) throws {
        let now = TestClock.date(day: 11, hour: 9, minute: 0)

        let result = plan([gas(isOn: isOn, [rule(.always, 3, .days)])], now: now)

        try #require(result.count == 1)
        #expect(result[0].title == "🔥 Газ горить")
        #expect(result[0].body == "Не перемикали вже 3 дні")
        #expect(result[0].payload == ReminderPayload(switchID: gasID, wasOn: isOn))
    }

    // MARK: - Хвилини й години — абсолютний час; дні — календарні

    @Test func minutesAreAbsoluteAcrossSpringForward() throws {
        // 29.03.2026 у Києві 03:00 → 04:00. 02:50 + 20 хв = 04:10 на годиннику.
        let reference = kyiv(3, 29, 2, 50)
        let snapshot = gas(isOn: true, lastToggledAt: .some(reference), [rule(.on, 20, .minutes)])

        let result = plan([snapshot], now: reference)

        try #require(result.count == 1)
        #expect(result[0].date == reference.addingTimeInterval(20 * 60))
        #expect(result[0].date == kyiv(3, 29, 4, 10))
    }

    @Test func hoursAreAbsoluteAcrossSpringForward() throws {
        // 24 години від 28.03 10:00 — це 29.03 11:00 на годиннику (доба 29.03 коротша на годину).
        let reference = kyiv(3, 28, 10, 0)
        let snapshot = gas(isOn: true, lastToggledAt: .some(reference), [rule(.on, 24, .hours)])

        let result = plan([snapshot], now: reference)

        try #require(result.count == 1)
        #expect(result[0].date == reference.addingTimeInterval(24 * 3600))
        #expect(result[0].date == kyiv(3, 29, 11, 0))
    }

    @Test func daysKeepClockTimeAcrossSpringForward() throws {
        // 28.03 10:00 + 1 день = 29.03 10:00 — минуло лише 23 години.
        let reference = kyiv(3, 28, 10, 0)
        let snapshot = gas(isOn: false, lastToggledAt: .some(reference), [rule(.always, 1, .days)])

        let result = plan([snapshot], now: reference)

        try #require(result.count == 1)
        #expect(result[0].date == kyiv(3, 29, 10, 0))
        #expect(result[0].date.timeIntervalSince(reference) == 23 * 3600)
        #expect(result[0].body == "Не перемикали вже 1 день")
    }

    @Test func daysKeepClockTimeAcrossFallBack() throws {
        // 25.10.2026 у Києві 04:00 → 03:00. 24.10 10:00 + 1 день = 25.10 10:00 — минуло 25 годин.
        let reference = kyiv(10, 24, 10, 0)
        let snapshot = gas(isOn: false, lastToggledAt: .some(reference), [rule(.always, 1, .days)])

        let result = plan([snapshot], now: reference)

        try #require(result.count == 1)
        #expect(result[0].date == kyiv(10, 25, 10, 0))
        #expect(result[0].date.timeIntervalSince(reference) == 25 * 3600)
        #expect(result[0].body == "Не перемикали вже 1 день")
    }

    // Дні рахуються в поясі переданого календаря, а не системного.
    @Test func daysUseTimeZoneOfGivenCalendar() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        // 07.03.2026 10:00 у Нью-Йорку; 08.03 там переводять годинник — 1 день = 23 години.
        let reference = newYork.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 10))!
        let snapshot = gas(isOn: false, lastToggledAt: .some(reference), [rule(.always, 1, .days)])

        let result = plan([snapshot], now: reference, calendar: newYork)

        try #require(result.count == 1)
        #expect(result[0].date.timeIntervalSince(reference) == 23 * 3600)
    }

    // MARK: - Повтор

    @Test func repeatingMinutesRuleAddsTwoMoreEveryTenMinutes() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        let result = plan([gas(isOn: true, [rule(.on, 30, .minutes, repeats: true)])], now: now)

        #expect(result.map(\.date) == [
            TestClock.date(day: 11, hour: 8, minute: 30),
            TestClock.date(day: 11, hour: 8, minute: 40),
            TestClock.date(day: 11, hour: 8, minute: 50)
        ])
        #expect(result.map(\.body) == ["Увімкнено вже 30 хв", "Увімкнено вже 40 хв", "Увімкнено вже 50 хв"])
        #expect(result.allSatisfy { $0.title == "🔥 Газ горить" })
        #expect(result.allSatisfy { $0.payload == ReminderPayload(switchID: gasID, wasOn: true) })
    }

    @Test func repeatingHoursRuleShowsHoursAndMinutes() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        let result = plan([gas(isOn: false, [rule(.off, 2, .hours, repeats: true)])], now: now)

        #expect(result.map(\.date) == [
            TestClock.date(day: 11, hour: 10, minute: 0),
            TestClock.date(day: 11, hour: 10, minute: 10),
            TestClock.date(day: 11, hour: 10, minute: 20)
        ])
        #expect(result.map(\.body) == ["Вимкнено вже 2 год", "Вимкнено вже 2 год 10 хв", "Вимкнено вже 2 год 20 хв"])
    }

    @Test func repeatingDaysRuleShowsWholeDays() {
        let now = TestClock.date(day: 11, hour: 9, minute: 0)

        let result = plan([gas(isOn: true, [rule(.always, 3, .days, repeats: true)])], now: now)

        #expect(result.map(\.date) == [
            TestClock.date(day: 14, hour: 8, minute: 0),
            TestClock.date(day: 14, hour: 8, minute: 10),
            TestClock.date(day: 14, hour: 8, minute: 20)
        ])
        #expect(result.map(\.body) == ["Не перемикали вже 3 дні", "Не перемикали вже 3 дні", "Не перемикали вже 3 дні"])
    }

    @Test func nonRepeatingRuleGivesSingleReminder() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        let result = plan([gas(isOn: true, [rule(.on, 2, .hours, repeats: false)])], now: now)

        #expect(result.map(\.date) == [TestClock.date(day: 11, hour: 10, minute: 0)])
    }

    // MARK: - Дати в минулому

    // Застосунок відкрили між першим і другим нагадуванням — лишаються 2-ге і 3-тє.
    @Test func openedBetweenFirstAndSecondKeepsOnlyFutureRepeats() {
        let now = TestClock.date(day: 11, hour: 8, minute: 35)

        let result = plan([gas(isOn: true, [rule(.on, 30, .minutes, repeats: true)])], now: now)

        #expect(result.map(\.date) == [
            TestClock.date(day: 11, hour: 8, minute: 40),
            TestClock.date(day: 11, hour: 8, minute: 50)
        ])
        #expect(result.map(\.body) == ["Увімкнено вже 40 хв", "Увімкнено вже 50 хв"])
    }

    @Test func reminderDueExactlyNowIsSkipped() {
        let now = TestClock.date(day: 11, hour: 8, minute: 30)

        let result = plan([gas(isOn: true, [rule(.on, 30, .minutes, repeats: true)])], now: now)

        #expect(result.map(\.date) == [
            TestClock.date(day: 11, hour: 8, minute: 40),
            TestClock.date(day: 11, hour: 8, minute: 50)
        ])
    }

    @Test func allRemindersInThePastGiveNothing() {
        let now = TestClock.date(day: 11, hour: 8, minute: 50)

        let result = plan([gas(isOn: true, [rule(.on, 30, .minutes, repeats: true)])], now: now)

        #expect(result.isEmpty)
    }

    @Test func switchWithoutRulesGivesNothing() {
        #expect(plan([gas([])], now: toggledAt).isEmpty)
    }

    // MARK: - Прожитий час для хвилин і годин

    // Хвилини й години — один форматер: менше 60 хв — «N хв», від 60 хв — «N год» або
    // «N год M хв»; години без верхньої межі, без днів.

    @Test func repeatsOfFiftyMinuteRuleCrossIntoHours() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        let result = plan([gas(isOn: true, [rule(.on, 50, .minutes, repeats: true)])], now: now)

        #expect(result.map(\.body) == ["Увімкнено вже 50 хв", "Увімкнено вже 1 год", "Увімкнено вже 1 год 10 хв"])
    }

    @Test(arguments: [
        (59, ReminderUnit.minutes, "59 хв"),
        (60, ReminderUnit.minutes, "1 год"),
        (90, ReminderUnit.minutes, "1 год 30 хв"),
        (150, ReminderUnit.minutes, "2 год 30 хв"),
        (1, ReminderUnit.hours, "1 год"),
        (23, ReminderUnit.hours, "23 год"),
        (24, ReminderUnit.hours, "24 год"),
        (36, ReminderUnit.hours, "36 год"),
        (100, ReminderUnit.hours, "100 год")
    ])
    func elapsedTimeForMinutesAndHours(amount: Int, unit: ReminderUnit, expected: String) throws {
        let result = plan([gas(isOn: false, [rule(.off, amount, unit)])], now: toggledAt)

        try #require(result.count == 1)
        #expect(result[0].body == "Вимкнено вже \(expected)")
    }

    @Test func repeatsOfLongHoursRuleStayInHours() {
        let result = plan([gas(isOn: true, [rule(.always, 36, .hours, repeats: true)])], now: toggledAt)

        #expect(result.map(\.body) == [
            "Не перемикали вже 36 год", "Не перемикали вже 36 год 10 хв", "Не перемикали вже 36 год 20 хв"
        ])
    }

    // MARK: - Кількість ≤ 0

    // Правило з нульовою чи від'ємною кількістю нічого не планує — ні першого сповіщення, ні повторів.
    @Test(arguments: [
        (0, ReminderUnit.minutes), (-5, ReminderUnit.minutes),
        (0, ReminderUnit.hours), (-1, ReminderUnit.hours),
        (0, ReminderUnit.days), (-1, ReminderUnit.days)
    ])
    func nonPositiveAmountPlansNothing(amount: Int, unit: ReminderUnit) {
        let result = plan([gas(isOn: true, [rule(.always, amount, unit, repeats: true)])], now: toggledAt)

        #expect(result.isEmpty)
    }

    // MARK: - Кількість понад 10 000

    // Кількість понад 10 000 (будь-яка одиниця) — правило нічого не планує, без переповнення й падіння.
    @Test(arguments: [
        (10_001, ReminderUnit.minutes), (10_001, ReminderUnit.hours), (10_001, ReminderUnit.days),
        (Int.max, ReminderUnit.minutes), (Int.max, ReminderUnit.hours), (Int.max, ReminderUnit.days)
    ])
    func tooLargeAmountPlansNothing(amount: Int, unit: ReminderUnit) {
        let result = plan([gas(isOn: true, [rule(.always, amount, unit, repeats: true)])], now: toggledAt)

        #expect(result.isEmpty)
    }

    // 10 000 — ще дозволено.
    @Test(arguments: [ReminderUnit.minutes, ReminderUnit.hours, ReminderUnit.days])
    func amountOfTenThousandIsStillPlanned(unit: ReminderUnit) {
        let result = plan([gas(isOn: true, [rule(.always, 10_000, unit, repeats: true)])], now: toggledAt)

        #expect(result.count == 3)
    }

    @Test func tooLargeRuleDoesNotAffectOtherRules() {
        let rules = [
            rule(.on, Int.max, .minutes, repeats: true, id: fixedUUID(1)),
            rule(.on, 30, .minutes, repeats: false, id: fixedUUID(2))
        ]

        let result = plan([gas(isOn: true, rules)], now: toggledAt)

        #expect(result.map(\.body) == ["Увімкнено вже 30 хв"])
    }

    @Test func nonPositiveRuleDoesNotAffectOtherRules() {
        let rules = [
            rule(.on, 0, .minutes, repeats: true, id: fixedUUID(1)),
            rule(.on, 30, .minutes, repeats: false, id: fixedUUID(2))
        ]

        let result = plan([gas(isOn: true, rules)], now: toggledAt)

        #expect(result.map(\.body) == ["Увімкнено вже 30 хв"])
    }

    // MARK: - Форми множини днів

    @Test(arguments: [
        (1, "1 день"), (2, "2 дні"), (3, "3 дні"), (4, "4 дні"), (5, "5 днів"),
        (11, "11 днів"), (12, "12 днів"), (13, "13 днів"), (14, "14 днів"), (20, "20 днів"),
        (21, "21 день"), (22, "22 дні"), (24, "24 дні"), (25, "25 днів"),
        (101, "101 день"), (111, "111 днів"), (112, "112 днів"), (122, "122 дні")
    ])
    func dayCountUsesUkrainianPluralForms(days: Int, expected: String) throws {
        let result = plan([gas(isOn: true, [rule(.always, days, .days)])], now: toggledAt)

        try #require(result.count == 1)
        #expect(result[0].body == "Не перемикали вже \(expected)")
    }

    // MARK: - Ідентифікатори

    @Test func identifiersAreDeterministic() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)
        let switches = [gas(isOn: true, [rule(.on, 30, .minutes, repeats: true, id: fixedUUID(1))])]

        let first = ReminderPlanner.plan(for: switches, now: now, calendar: calendar)
        let second = ReminderPlanner.plan(for: switches, now: now, calendar: calendar)

        #expect(first == second)
        #expect(Set(first.map(\.id)).count == 3, "Перше сповіщення і два повтори мають різні id")
    }

    // Повтор зберігає свій id, хоч би коли планували: перепланування замінює запит, а не дублює.
    @Test func repeatKeepsItsIdentifierWhenEarlierOnesArePast() throws {
        let switches = [gas(isOn: true, [rule(.on, 30, .minutes, repeats: true, id: fixedUUID(1))])]

        let early = plan(switches, now: TestClock.date(day: 11, hour: 8, minute: 5))
        let later = plan(switches, now: TestClock.date(day: 11, hour: 8, minute: 35))

        try #require(early.count == 3)
        #expect(later.map(\.id) == Array(early.map(\.id).dropFirst()))
    }

    @Test func differentRulesGetDifferentIdentifiers() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)
        let first = rule(.on, 30, .minutes, repeats: true, id: fixedUUID(1))
        let second = rule(.on, 30, .minutes, repeats: true, id: fixedUUID(2))

        let ids = plan([gas(isOn: true, [first, second])], now: now).map(\.id)

        #expect(ids.count == 6)
        #expect(Set(ids).count == 6)
    }

    @Test func sameRuleUUIDUnderDifferentSwitchesGetsDifferentIdentifiers() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)
        let shared = rule(.on, 30, .minutes, id: fixedUUID(1))

        let ids = plan([gas(isOn: true, id: fixedUUID(100), [shared]), gas(isOn: true, id: fixedUUID(101), [shared])], now: now)
            .map(\.id)

        #expect(ids.count == 2)
        #expect(Set(ids).count == 2)
    }

    // MARK: - Кілька правил і перемикачів, межа 64

    @Test func allRulesOfAllSwitchesArePlannedTogether() {
        let now = TestClock.date(day: 11, hour: 8, minute: 5)
        let gasSwitch = gas(isOn: true, [
            rule(.on, 30, .minutes, id: fixedUUID(1)),
            rule(.always, 2, .hours, id: fixedUUID(2)),
            rule(.off, 10, .minutes, id: fixedUUID(3)) // не діє: газ увімкнено
        ])
        let flowersSwitch = flowers(isOn: false, lastToggledAt: TestClock.date(day: 10, hour: 20, minute: 0), [
            rule(.always, 1, .days, id: fixedUUID(4))
        ])

        let result = plan([gasSwitch, flowersSwitch], now: now)

        #expect(result.map(\.date) == [
            TestClock.date(day: 11, hour: 8, minute: 30),
            TestClock.date(day: 11, hour: 10, minute: 0),
            TestClock.date(day: 11, hour: 20, minute: 0)
        ])
        #expect(result.map(\.title) == ["🔥 Газ горить", "🔥 Газ горить", "🪴 Полила квіти"])
        #expect(result.map(\.body) == ["Увімкнено вже 30 хв", "Не перемикали вже 2 год", "Не перемикали вже 1 день"])
        #expect(result.map(\.payload) == [
            ReminderPayload(switchID: gasID, wasOn: true),
            ReminderPayload(switchID: gasID, wasOn: true),
            ReminderPayload(switchID: flowersID, wasOn: false)
        ])
    }

    @Test func moreThanSixtyFourKeepsTheEarliest() {
        // Газ: правила на 1, 3, 5 … 79 хв; квіти: 2, 4 … 80 хв — разом 80 сповіщень, по одному на хвилину.
        let gasRules = (0..<40).map { rule(.on, 2 * $0 + 1, .minutes, id: fixedUUID(1_000 + $0)) }
        let flowersRules = (0..<40).map { rule(.on, 2 * $0 + 2, .minutes, id: fixedUUID(2_000 + $0)) }
        let switches = [
            gas(isOn: true, gasRules),
            flowers(isOn: true, lastToggledAt: toggledAt, flowersRules)
        ]

        let result = plan(switches, now: toggledAt)

        #expect(ReminderPlanner.limit == 64)
        #expect(result.count == 64)
        #expect(result.map(\.date) == (1...64).map { toggledAt.addingTimeInterval(Double($0) * 60) })
    }

    @Test func limitCountsRepeatsToo() {
        // 22 правила з повтором — 66 сповіщень; лишаються 64 найраніші, два найпізніші відкинуто.
        let rules = (0..<22).map { rule(.on, 60 * ($0 + 1), .minutes, repeats: true, id: fixedUUID(3_000 + $0)) }

        let result = plan([gas(isOn: true, rules)], now: toggledAt)

        #expect(result.count == 64)
        let latestKept = toggledAt.addingTimeInterval(Double(22 * 60 * 60))
        #expect(result.last?.date == latestKept, "Відкинуто мали бути два повтори останнього правила")
    }

    // MARK: - Ізоляція

    // Планувальник не прив'язаний до головного актора: його можна викликати з фонового завдання.
    @Test func plannerRunsOffTheMainActor() async {
        let switches = [gas(isOn: true, [rule(.on, 30, .minutes)])]
        let now = TestClock.date(day: 11, hour: 8, minute: 5)
        let kyivCalendar = calendar

        let result = await Task.detached {
            ReminderPlanner.plan(for: switches, now: now, calendar: kyivCalendar)
        }.value

        #expect(result.count == 1)
    }
}

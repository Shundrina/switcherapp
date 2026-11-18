import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Switcher

// Перепланування: `ReminderScheduler` працює з центром сповіщень через протокол
// `ReminderNotificationCenter` (у застосунку — `UNUserNotificationCenter`, у тестах — фейк нижче).
// `reschedule` прибирає наші заплановані запити й додає план з `ReminderPlanner`; запити несуть
// категорію з кнопкою «Перемкнути». `removeDelivered(forSwitch:)` після перемикання прибирає вже
// показані сповіщення цього перемикача.

/// Центр сповіщень у пам'яті. Як і справжній, `add` із тим самим id замінює запит.
@MainActor
final class FakeNotificationCenter: ReminderNotificationCenter {
    struct AddFailure: Error {}

    private(set) var pending: [UNNotificationRequest] = []
    var delivered: [UNNotificationRequest] = []

    /// Номер виклику `add` (з 1), який кине `AddFailure`; запит при цьому не додається.
    var failingAddCall: Int?
    private(set) var addCalls = 0

    /// Режим «повільного центру»: `pendingNotificationRequests` чекає, доки тест не відпустить
    /// (`releaseNewestPendingQuery`). Відповідь — `pending` на момент відпускання, як у справжнього
    /// центру, чиї асинхронні відповіді можуть приходити в будь-якому порядку.
    var holdsPendingQueries = false
    private var heldPendingQueries: [CheckedContinuation<Void, Never>] = []
    var heldPendingQueryCount: Int { heldPendingQueries.count }

    func add(_ request: UNNotificationRequest) throws {
        addCalls += 1
        if addCalls == failingAddCall { throw AddFailure() }
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    /// Запит не від планувальника — наприклад, від майбутньої функції застосунку.
    func addForeign(_ request: UNNotificationRequest) {
        pending.append(request)
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        if holdsPendingQueries {
            await withCheckedContinuation { heldPendingQueries.append($0) }
        }
        return pending
    }

    /// Відпускає запит `pendingNotificationRequests`, який надійшов останнім.
    func releaseNewestPendingQuery() {
        heldPendingQueries.popLast()?.resume()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        pending.removeAll { identifiers.contains($0.identifier) }
    }

    func deliveredNotificationRequests() -> [UNNotificationRequest] {
        delivered
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        delivered.removeAll { identifiers.contains($0.identifier) }
    }
}

/// Прапорець «завдання завершилося» для тестів з одночасними викликами.
@MainActor
final class Flag {
    var isSet = false
}

@MainActor
struct ReminderSchedulerTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let center = FakeNotificationCenter()
    let scheduler: ReminderScheduler
    let calendar = TestClock.calendar
    let turnedOnAt = TestClock.date(day: 11, hour: 8, minute: 0)

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
        scheduler = ReminderScheduler(center: center)
    }

    private func makeItem(_ name: String, icon: String, isOn: Bool) -> SwitchItem {
        let item = SwitchItem(name: name, icon: SwitchIcon(rawValue: icon)!, createdAt: TestClock.date(day: 1, hour: 9, minute: 0))
        context.insert(item)
        if isOn {
            item.setOn(true, at: turnedOnAt)
        }
        return item
    }

    @discardableResult
    private func addRule(to item: SwitchItem, _ condition: ReminderCondition, _ amount: Int, _ unit: ReminderUnit,
                         repeats: Bool) -> ReminderRule {
        let rule = ReminderRule(condition: condition, amount: amount, unit: unit, repeats: repeats)
        context.insert(rule)
        rule.item = item
        return rule
    }

    private func allItems() throws -> [SwitchItem] {
        try context.fetch(FetchDescriptor<SwitchItem>())
    }

    private func reschedule(at now: Date) async throws {
        try await scheduler.reschedule(try allItems(), now: now, calendar: calendar)
    }

    /// Тексти запланованих запитів, відсортовані.
    private var pendingBodies: [String] {
        center.pending.map(\.content.body).sorted()
    }

    // MARK: - Що потрапляє в запит

    @Test func reschedulePlansRequestsFromRules() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try context.save()
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        try await reschedule(at: now)

        let expected = ReminderPlanner.plan(for: [ReminderSwitchSnapshot(gas)], now: now, calendar: calendar)
        #expect(expected.count == 3)
        #expect(Set(center.pending.map(\.identifier)) == Set(expected.map(\.id)))
        #expect(pendingBodies == ["Увімкнено вже 30 хв", "Увімкнено вже 40 хв", "Увімкнено вже 50 хв"])
        for request in center.pending {
            #expect(request.content.title == "🔥 Газ горить")
            #expect(request.content.categoryIdentifier == ReminderNotifications.categoryID)
            #expect(ReminderPayload(userInfo: request.content.userInfo) == ReminderPayload(switchID: gas.uuid, wasOn: true))
            let trigger = try #require(request.trigger, "Запит без тригера показався б одразу")
            #expect(trigger.repeats == false)
        }
        // Тригер — інтервал від `now` до дати нагадування: 08:30, 08:40, 08:50 від 08:05.
        let intervalsByBody = Dictionary(uniqueKeysWithValues: center.pending.map { request in
            (request.content.body, (request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval)
        })
        #expect(intervalsByBody == [
            "Увімкнено вже 30 хв": 25 * 60,
            "Увімкнено вже 40 хв": 35 * 60,
            "Увімкнено вже 50 хв": 45 * 60
        ])
    }

    // MARK: - Чужі запити, помилки, одночасні виклики

    @Test func foreignPendingRequestSurvivesReschedule() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        let foreign = UNNotificationRequest(identifier: "чуже", content: UNMutableNotificationContent(),
                                            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 600, repeats: false))
        center.addForeign(foreign)

        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 6))

        #expect(center.pending.count == 4)
        #expect(center.pending.contains { $0.identifier == "чуже" })
    }

    // Один запит не вдалося додати — решта плану все одно додана, а помилка доходить до викликача.
    @Test func failedAddDoesNotStopTheRestOfThePlan() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        addRule(to: gas, .always, 2, .hours, repeats: false)
        let now = TestClock.date(day: 11, hour: 8, minute: 5)
        let plan = ReminderPlanner.plan(for: [ReminderSwitchSnapshot(gas)], now: now, calendar: calendar)
        try #require(plan.count == 4)
        center.failingAddCall = 2

        await #expect(throws: (any Error).self) {
            try await scheduler.reschedule(try allItems(), now: now, calendar: calendar)
        }

        #expect(center.addCalls == 4, "Після помилки решту запитів не намагалися додати")
        #expect(center.pending.count == 3)
        #expect(Set(center.pending.map(\.identifier)).isSubset(of: Set(plan.map(\.id))))
    }

    // Два перепланування одночасно: спершу для стану «увімкнено», потім — «вимкнено». Відповіді
    // центру приходять у зворотному порядку. Після обох у центрі має бути рівно план останнього стану.
    @Test func concurrentReschedulesEndWithPlanOfLatestState() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        addRule(to: gas, .off, 2, .hours, repeats: true)
        let items = try allItems()
        center.holdsPendingQueries = true

        let firstDone = Flag(), secondDone = Flag()
        let first = Task {
            defer { firstDone.isSet = true }
            try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 5), calendar: calendar)
        }
        await letOtherTasksRun()

        let turnedOffAt = TestClock.date(day: 11, hour: 8, minute: 10)
        gas.setOn(false, at: turnedOffAt)
        let second = Task {
            defer { secondDone.isSet = true }
            try await scheduler.reschedule(items, now: turnedOffAt, calendar: calendar)
        }
        await letOtherTasksRun()

        // Відпускаємо запити до центру від найновішого до найстарішого, доки обидва виклики не завершаться.
        var rounds = 0
        while !(firstDone.isSet && secondDone.isSet) && rounds < 200 {
            center.releaseNewestPendingQuery()
            await letOtherTasksRun()
            rounds += 1
        }
        center.holdsPendingQueries = false
        while center.heldPendingQueryCount > 0 { center.releaseNewestPendingQuery() }
        try #require(firstDone.isSet && secondDone.isSet, "Перепланування не завершилися")
        try await first.value
        try await second.value

        #expect(pendingBodies == ["Вимкнено вже 2 год", "Вимкнено вже 2 год 10 хв", "Вимкнено вже 2 год 20 хв"])
        for request in center.pending {
            #expect(ReminderPayload(userInfo: request.content.userInfo) == ReminderPayload(switchID: gas.uuid, wasOn: false))
        }
    }

    /// Дає завданням на головному акторі дійти до наступної точки очікування.
    private func letOtherTasksRun() async {
        for _ in 0..<20 { await Task.yield() }
    }

    // MARK: - Перемикач видалили, а масив для перепланування старий

    /// Газ (правило «увімкнено», 30 хв, з повтором) і квіти (створено 1 листопада, «не перемикали» 14 днів —
    /// нагадування 15 листопада).
    private func makeGasAndFlowers() throws -> (gas: SwitchItem, flowers: SwitchItem) {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        let flowers = makeItem("Полила квіти", icon: "🪴", isOn: false)
        addRule(to: flowers, .always, 14, .days, repeats: false)
        try context.save()
        return (gas, flowers)
    }

    /// Лише план квітів — і жодного запиту видаленого газу.
    private func expectOnlyFlowersPlan(flowersID: UUID, gasID: UUID) {
        #expect(center.pending.map(\.content.title) == ["🪴 Полила квіти"])
        #expect(pendingBodies == ["Не перемикали вже 14 днів"])
        #expect(!center.pending.contains { ReminderPayload(userInfo: $0.content.userInfo)?.switchID == gasID })
        #expect(center.pending.allSatisfy { ReminderPayload(userInfo: $0.content.userInfo)?.switchID == flowersID })
    }

    // Масив узято до видалення (наприклад, з @Query), а перепланування відбулося вже після `save()`.
    @Test func rescheduleWithStaleArraySkipsDeletedSwitch() async throws {
        let (gas, flowers) = try makeGasAndFlowers()
        let gasID = gas.uuid, flowersID = flowers.uuid
        let items = try allItems()
        try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 5), calendar: calendar)
        try #require(center.pending.count == 4)

        SwitchDeletion.delete(gas, from: context)
        try context.save()
        try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 6), calendar: calendar)

        expectOnlyFlowersPlan(flowersID: flowersID, gasID: gasID)
    }

    // Застосунок покладається на автозбереження: перепланування може статися одразу після видалення,
    // ще до `save()` (об'єкт позначено видаленим, але він і його правила ще читаються).
    @Test func rescheduleRightAfterDeleteBeforeSaveSkipsDeletedSwitch() async throws {
        let (gas, flowers) = try makeGasAndFlowers()
        let gasID = gas.uuid, flowersID = flowers.uuid
        let items = try allItems()
        try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 5), calendar: calendar)
        try #require(center.pending.count == 4)

        SwitchDeletion.delete(gas, from: context)
        try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 6), calendar: calendar)

        expectOnlyFlowersPlan(flowersID: flowersID, gasID: gasID)
    }

    // Другий виклик чекає в черзі, доки триває перший; перемикач видаляють, поки другий чекає.
    @Test func queuedRescheduleSkipsSwitchDeletedWhileWaiting() async throws {
        let (gas, flowers) = try makeGasAndFlowers()
        let gasID = gas.uuid, flowersID = flowers.uuid
        let items = try allItems()
        center.holdsPendingQueries = true

        let firstDone = Flag(), secondDone = Flag()
        let first = Task {
            defer { firstDone.isSet = true }
            try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 5), calendar: calendar)
        }
        await letOtherTasksRun()
        let second = Task {
            defer { secondDone.isSet = true }
            try await scheduler.reschedule(items, now: TestClock.date(day: 11, hour: 8, minute: 6), calendar: calendar)
        }
        await letOtherTasksRun()

        SwitchDeletion.delete(gas, from: context)
        try context.save()

        var rounds = 0
        while !(firstDone.isSet && secondDone.isSet) && rounds < 200 {
            center.releaseNewestPendingQuery()
            await letOtherTasksRun()
            rounds += 1
        }
        center.holdsPendingQueries = false
        while center.heldPendingQueryCount > 0 { center.releaseNewestPendingQuery() }
        try #require(firstDone.isSet && secondDone.isSet, "Перепланування не завершилися")
        try await first.value
        try await second.value

        expectOnlyFlowersPlan(flowersID: flowersID, gasID: gasID)
    }

    @Test func snapshotCarriesSwitchAndRules() throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        let rule = addRule(to: gas, .always, 3, .days, repeats: true)

        let snapshot = ReminderSwitchSnapshot(gas)

        #expect(snapshot.id == gas.uuid)
        #expect(snapshot.name == "Газ горить")
        #expect(snapshot.icon.rawValue == "🔥")
        #expect(snapshot.isOn == true)
        #expect(snapshot.createdAt == TestClock.date(day: 1, hour: 9, minute: 0))
        #expect(snapshot.lastToggledAt == turnedOnAt)
        #expect(snapshot.rules == [
            ReminderRuleSnapshot(id: rule.uuid, condition: .always, amount: 3, unit: .days, repeats: true)
        ])
    }

    @Test func switchWithoutRulesSchedulesNothing() async throws {
        _ = makeItem("Газ горить", icon: "🔥", isOn: true)

        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))

        #expect(center.pending.isEmpty)
    }

    // MARK: - Перепланування після змін

    @Test func rescheduleTwiceDoesNotDuplicate() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        let now = TestClock.date(day: 11, hour: 8, minute: 5)

        try await reschedule(at: now)
        try await reschedule(at: now)

        #expect(center.pending.count == 3)
    }

    @Test func turningSwitchOffReplacesPlan() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        addRule(to: gas, .off, 2, .hours, repeats: true)
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        #expect(pendingBodies == ["Увімкнено вже 30 хв", "Увімкнено вже 40 хв", "Увімкнено вже 50 хв"])

        let turnedOffAt = TestClock.date(day: 11, hour: 8, minute: 10)
        gas.setOn(false, at: turnedOffAt)
        try await reschedule(at: turnedOffAt)

        #expect(pendingBodies == ["Вимкнено вже 2 год", "Вимкнено вже 2 год 10 хв", "Вимкнено вже 2 год 20 хв"])
        for request in center.pending {
            #expect(ReminderPayload(userInfo: request.content.userInfo) == ReminderPayload(switchID: gas.uuid, wasOn: false))
        }
    }

    @Test func turningSwitchOffWithOnlyOnRuleClearsPlan() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        #expect(center.pending.count == 3)

        gas.setOn(false, at: TestClock.date(day: 11, hour: 8, minute: 10))
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 10))

        #expect(center.pending.isEmpty)
    }

    @Test func editingRuleReplacesPlan() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        let rule = addRule(to: gas, .on, 30, .minutes, repeats: true)
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        #expect(center.pending.count == 3)

        rule.amount = 15
        rule.repeats = false
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 6))

        #expect(pendingBodies == ["Увімкнено вже 15 хв"])
    }

    @Test func deletingRuleRemovesItsRequests() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        let minutes = addRule(to: gas, .on, 30, .minutes, repeats: true)
        addRule(to: gas, .always, 2, .hours, repeats: false)
        try context.save()
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        #expect(center.pending.count == 4)

        context.delete(minutes)
        try context.save()
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 6))

        #expect(pendingBodies == ["Не перемикали вже 2 год"])
    }

    @Test func deletingSwitchRemovesItsRequests() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        // Квіти створено 1 листопада й ще не перемикали: 14 днів від створення — 15 листопада.
        let flowers = makeItem("Полила квіти", icon: "🪴", isOn: false)
        addRule(to: flowers, .always, 14, .days, repeats: false)
        try context.save()
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        #expect(center.pending.count == 4)

        SwitchDeletion.delete(gas, from: context)
        try context.save()
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 6))

        #expect(center.pending.map(\.content.title) == ["🪴 Полила квіти"])
        #expect(pendingBodies == ["Не перемикали вже 14 днів"])
    }

    @Test func deletingLastSwitchClearsPlan() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))
        #expect(center.pending.count == 3)

        SwitchDeletion.delete(gas, from: context)
        try context.save()
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 6))

        #expect(center.pending.isEmpty)
    }

    // MARK: - Показані сповіщення

    /// Показане сповіщення так, як його запланував би планувальник.
    private func deliveredRequests(for item: SwitchItem, now: Date) -> [UNNotificationRequest] {
        let snapshot = ReminderSwitchSnapshot(item)
        return ReminderPlanner.plan(for: [snapshot], now: now, calendar: calendar).map { reminder in
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.userInfo = reminder.payload.userInfo
            content.categoryIdentifier = ReminderNotifications.categoryID
            return UNNotificationRequest(identifier: reminder.id, content: content, trigger: nil)
        }
    }

    @Test func removeDeliveredClearsOnlyThatSwitch() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        let iron = makeItem("Праска", icon: "🔌", isOn: true)
        addRule(to: iron, .on, 1, .hours, repeats: false)
        let planningTime = TestClock.date(day: 11, hour: 8, minute: 5)
        let foreign = UNNotificationRequest(identifier: "чуже", content: UNMutableNotificationContent(), trigger: nil)
        center.delivered = deliveredRequests(for: gas, now: planningTime)
            + deliveredRequests(for: iron, now: planningTime)
            + [foreign]
        try #require(center.delivered.count == 5)
        let ironIDs = center.delivered.filter { $0.content.title == "🔌 Праска" }.map(\.identifier)

        await scheduler.removeDelivered(forSwitch: gas.uuid)

        #expect(center.delivered.map(\.identifier) == ironIDs + ["чуже"])
    }

    @Test func removeDeliveredLeavesPendingAlone() async throws {
        let gas = makeItem("Газ горить", icon: "🔥", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try await reschedule(at: TestClock.date(day: 11, hour: 8, minute: 5))

        await scheduler.removeDelivered(forSwitch: gas.uuid)

        #expect(center.pending.count == 3)
    }
}

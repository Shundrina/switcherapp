import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Switcher

// `ReminderService` — підключення нагадувань до застосунку (етап 1, частина «б»): спільний
// `ModelContainer`, центр сповіщень (`ReminderNotificationCenter`), дозвіл (`NotificationAuthorizing`),
// системні події часу (ті самі, що в `CurrentDateRefresh`), годинник і календар — усе передається явно.
//
// - `start()` при запуску: реєструє категорію з кнопкою «Перемкнути», лагодить дублікати UUID
//   (порядок за `createdAt`, зміни зберігаються), читає дозвіл і перепланує.
// - `refresh()` — при переході в `active`: перечитує дозвіл (могли увімкнути в Параметрах) і перепланує.
// - Зміна поясу, системного часу, новий день — перепланування з новим годинником і календарем.
// - `didToggle(_:)` після перемикання в застосунку: прибирає показані сповіщення перемикача й перепланує.
// - `handleNotificationResponse(actionIdentifier:userInfo:)` — відповідь на сповіщення: для «Перемкнути» —
//   `ReminderToggle.perform`, прибирання показаних сповіщень перемикача й перепланування.
// - `requestPermissionIfNeeded()` — при збереженні правила: питає лише коли дозвіл «не визначено».

private func fixedUUID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
}

/// Годинник і календар, які тест пересуває.
final class MutableClock {
    var now: Date
    var calendar: Calendar

    init(now: Date, calendar: Calendar = TestClock.calendar) {
        self.now = now
        self.calendar = calendar
    }
}

/// Дозвіл на сповіщення в пам'яті: `answer` — що «відповість користувачка» на запит.
@MainActor
final class FakeNotificationAuthorization: NotificationAuthorizing {
    var status: NotificationPermission
    var answer: NotificationPermission
    private(set) var requestCount = 0

    init(status: NotificationPermission, answer: NotificationPermission = .allowed) {
        self.status = status
        self.answer = answer
    }

    func permission() -> NotificationPermission {
        status
    }

    func requestPermission() -> NotificationPermission {
        requestCount += 1
        status = answer
        return status
    }
}

@MainActor
struct ReminderServiceTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let center = FakeNotificationCenter()
    let authorization = FakeNotificationAuthorization(status: .allowed)
    let systemEvents = NotificationCenter()
    let clock = MutableClock(now: TestClock.date(day: 11, hour: 8, minute: 5))
    let service: ReminderService
    let ruleEditedAt = TestClock.date(day: 1, hour: 9, minute: 0)

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
        let testClock = self.clock
        service = ReminderService(
            container: container, center: center, authorization: authorization, systemEvents: systemEvents,
            now: { testClock.now }, calendar: { testClock.calendar }
        )
    }

    @discardableResult
    private func makeItem(_ name: String, icon: String = "🔥", isOn: Bool,
                          createdAt: Date = TestClock.date(day: 1, hour: 9, minute: 0),
                          toggledAt: Date = TestClock.date(day: 11, hour: 8, minute: 0)) -> SwitchItem {
        let item = SwitchItem(name: name, icon: SwitchIcon(rawValue: icon)!, createdAt: createdAt)
        context.insert(item)
        if isOn {
            item.setOn(true, at: toggledAt)
        }
        return item
    }

    @discardableResult
    private func addRule(to item: SwitchItem, _ condition: ReminderCondition, _ amount: Int, _ unit: ReminderUnit,
                         repeats: Bool) -> ReminderRule {
        let rule = ReminderRule(condition: condition, amount: amount, unit: unit, repeats: repeats, editedAt: ruleEditedAt)
        context.insert(rule)
        rule.item = item
        return rule
    }

    private var pendingBodies: [String] {
        center.pending.map(\.content.body).sorted()
    }

    /// Інтервали тригерів (секунди від моменту планування), відсортовані.
    private var pendingIntervals: [TimeInterval] {
        center.pending.compactMap { ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval }.sorted()
    }

    private func minutes(_ values: Double...) -> [TimeInterval] {
        values.map { $0 * 60 }
    }

    private func hours(_ values: Double...) -> [TimeInterval] {
        values.map { $0 * 3600 }
    }

    /// Чекає (до 2 с), поки умова стане істинною: реакція на системні сповіщення може бути асинхронною.
    private func eventually(_ condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return condition()
    }

    /// Показані сповіщення перемикача — такі, як їх запланував би планувальник.
    private func delivered(for item: SwitchItem) -> [UNNotificationRequest] {
        ReminderPlanner.plan(for: [ReminderSwitchSnapshot(item)], now: clock.now, calendar: clock.calendar).map { reminder in
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.userInfo = reminder.payload.userInfo
            content.categoryIdentifier = ReminderNotifications.categoryID
            return UNNotificationRequest(identifier: reminder.id, content: content, trigger: nil)
        }
    }

    // MARK: - Запуск

    @Test func startRegistersToggleCategory() async {
        await service.start()

        let category = center.categories.first { $0.identifier == ReminderNotifications.categoryID }
        #expect(category?.actions.map(\.identifier) == [ReminderNotifications.toggleActionID])
    }

    @Test func startSchedulesPlanForStoredSwitches() async throws {
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try context.save()

        await service.start()

        #expect(pendingBodies == ["Увімкнено вже 30 хв", "Увімкнено вже 40 хв", "Увімкнено вже 50 хв"])
        #expect(pendingIntervals == minutes(25, 35, 45))
    }

    // Після легкої міграції в усіх перемикачів той самий UUID. Найстаріший (за `createdAt`) його зберігає,
    // інші отримують нові — ще до планування, і це збережено в сховищі.
    @Test func startRepairsDuplicateUUIDsByCreationOrderBeforeScheduling() async throws {
        let shared = fixedUUID(7)
        // Вставлено в зворотному порядку: порядок має братися з `createdAt`, а не з порядку вставки.
        let newer = makeItem("Праска", icon: "🔌", isOn: true, createdAt: TestClock.date(day: 3, hour: 9, minute: 0))
        let older = makeItem("Газ горить", isOn: true, createdAt: TestClock.date(day: 1, hour: 9, minute: 0))
        newer.uuid = shared
        older.uuid = shared
        addRule(to: newer, .on, 30, .minutes, repeats: false)
        addRule(to: older, .on, 30, .minutes, repeats: false)
        try context.save()

        await service.start()

        #expect(older.uuid == shared)
        #expect(newer.uuid != shared)
        let payloadIDs = Set(center.pending.compactMap { ReminderPayload(userInfo: $0.content.userInfo)?.switchID })
        #expect(payloadIDs == [older.uuid, newer.uuid])

        let stored = try ModelContext(container).fetch(FetchDescriptor<SwitchItem>())
        #expect(Set(stored.map(\.uuid)) == [older.uuid, newer.uuid], "Нові UUID не збережено в сховищі")
    }

    @Test(arguments: [NotificationPermission.notDetermined, .denied, .allowed])
    func startReadsPermissionWithoutAsking(status: NotificationPermission) async {
        authorization.status = status

        await service.start()

        #expect(service.permission == status)
        #expect(authorization.requestCount == 0, "Дозвіл питають лише при збереженні правила")
    }

    // MARK: - Повернення в застосунок і системні події часу

    @Test func refreshReschedulesFromCurrentClock() async throws {
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try context.save()
        await service.start()
        #expect(pendingIntervals == minutes(25, 35, 45))

        clock.now = TestClock.date(day: 11, hour: 8, minute: 15)
        await service.refresh()

        #expect(pendingIntervals == minutes(15, 25, 35))
    }

    // Сповіщення вимкнули, користувачка увімкнула їх у Параметрах і повернулася: напис має зникнути.
    @Test func refreshRereadsPermission() async {
        authorization.status = .denied
        await service.start()
        #expect(service.permission == .denied)

        authorization.status = .allowed
        await service.refresh()

        #expect(service.permission == .allowed)
    }

    @Test(arguments: CurrentDateRefresh.notificationNames)
    func systemTimeEventReschedules(name: Notification.Name) async throws {
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try context.save()
        await service.start()
        #expect(pendingIntervals == minutes(25, 35, 45))

        clock.now = TestClock.date(day: 11, hour: 8, minute: 15)
        systemEvents.post(name: name, object: nil)

        #expect(await eventually { pendingIntervals == minutes(15, 25, 35) },
                "Після \(name.rawValue) не переплановано: \(pendingIntervals)")
    }

    // Новий пояс: правило в днях знову рахується «та сама година на годиннику», тепер — у новому поясі.
    // 31.10.2026 → 01.11.2026: у Києві доба звичайна (24 год), у Нью-Йорку 1 листопада переводять годинник (25 год).
    @Test func timeZoneChangeReplansDaysInNewZone() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let toggled = utc.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 12))!
        clock.now = toggled.addingTimeInterval(30 * 60)
        let flowers = makeItem("Полила квіти", icon: "🪴", isOn: false, createdAt: toggled.addingTimeInterval(-86_400))
        flowers.setOn(true, at: toggled.addingTimeInterval(-60))
        flowers.setOn(false, at: toggled)
        let rule = addRule(to: flowers, .always, 1, .days, repeats: false)
        rule.editedAt = toggled
        try context.save()
        await service.start()
        #expect(pendingIntervals == hours(23.5))

        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = TimeZone(identifier: "America/New_York")!
        clock.calendar = newYork
        systemEvents.post(name: .NSSystemTimeZoneDidChange, object: nil)

        #expect(await eventually { pendingIntervals == hours(24.5) }, "Інтервал після зміни поясу: \(pendingIntervals)")
    }

    // MARK: - Перемикання в застосунку

    @Test func didToggleRemovesDeliveredOfThatSwitchAndReschedules() async throws {
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        addRule(to: gas, .off, 2, .hours, repeats: false)
        let iron = makeItem("Праска", icon: "🔌", isOn: true)
        addRule(to: iron, .on, 1, .hours, repeats: false)
        try context.save()
        await service.start()
        center.delivered = delivered(for: gas) + delivered(for: iron)
        let ironDelivered = delivered(for: iron).map(\.identifier)

        clock.now = TestClock.date(day: 11, hour: 8, minute: 10)
        gas.setOn(false, at: clock.now)
        await service.didToggle(gas)

        #expect(center.delivered.map(\.identifier) == ironDelivered)
        #expect(pendingBodies == ["Вимкнено вже 2 год", "Увімкнено вже 1 год"])
    }

    // MARK: - Відповідь на сповіщення

    @Test func toggleActionTogglesSwitchClearsDeliveredAndReschedules() async throws {
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        addRule(to: gas, .off, 2, .hours, repeats: false)
        try context.save()
        await service.start()
        center.delivered = delivered(for: gas)
        clock.now = TestClock.date(day: 11, hour: 8, minute: 31)

        await service.handleNotificationResponse(
            actionIdentifier: ReminderNotifications.toggleActionID,
            userInfo: ReminderPayload(switchID: gas.uuid, wasOn: true).userInfo
        )

        #expect(gas.isOn == false)
        #expect(gas.lastToggledAt == clock.now)
        #expect(gas.sortedEvents.first?.isOn == false)
        #expect(gas.sortedEvents.first?.timestamp == clock.now)
        #expect(center.delivered.isEmpty)
        #expect(pendingBodies == ["Вимкнено вже 2 год"])
    }

    // Натискання на саме сповіщення чи його закриття не перемикає.
    @Test(arguments: [UNNotificationDefaultActionIdentifier, UNNotificationDismissActionIdentifier])
    func otherActionsDoNotToggle(actionIdentifier: String) async throws {
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try context.save()
        await service.start()

        await service.handleNotificationResponse(
            actionIdentifier: actionIdentifier,
            userInfo: ReminderPayload(switchID: gas.uuid, wasOn: true).userInfo
        )

        #expect(gas.isOn == true)
        #expect(gas.sortedEvents.count == 1)
        #expect(center.pending.count == 3)
    }

    // MARK: - Дозвіл

    // Перше збереження правила: дозвіл «не визначено» — питаємо; відповідь стає станом сервісу.
    @Test(arguments: [NotificationPermission.allowed, .denied])
    func undeterminedPermissionIsRequested(answer: NotificationPermission) async {
        authorization.status = .notDetermined
        authorization.answer = answer
        await service.start()

        await service.requestPermissionIfNeeded()

        #expect(authorization.requestCount == 1)
        #expect(service.permission == answer)
    }

    // Уже дозволено чи вже відмовлено — системне вікно вдруге не показується.
    @Test(arguments: [NotificationPermission.allowed, .denied])
    func decidedPermissionIsNotRequestedAgain(status: NotificationPermission) async {
        authorization.status = status
        await service.start()

        await service.requestPermissionIfNeeded()
        await service.requestPermissionIfNeeded()

        #expect(authorization.requestCount == 0)
        #expect(service.permission == status)
    }

    // Дозволили — план, складений до дозволу, лишається (перепланування після правила не губиться).
    @Test func allowingKeepsScheduledPlan() async throws {
        authorization.status = .notDetermined
        authorization.answer = .allowed
        let gas = makeItem("Газ горить", isOn: true)
        addRule(to: gas, .on, 30, .minutes, repeats: true)
        try context.save()
        await service.start()

        await service.requestPermissionIfNeeded()

        #expect(center.pending.count == 3)
    }
}

/// Показ сповіщення, коли застосунок відкритий, і стан дозволу з системного.
@MainActor
struct ReminderPresentationTests {
    @Test func openAppShowsBannerWithSound() {
        let options = ReminderNotifications.presentationOptions

        #expect(options.contains(.banner))
        #expect(options.contains(.sound))
    }

    @Test(arguments: [
        (UNAuthorizationStatus.notDetermined, NotificationPermission.notDetermined),
        (UNAuthorizationStatus.denied, NotificationPermission.denied),
        (UNAuthorizationStatus.authorized, NotificationPermission.allowed),
        (UNAuthorizationStatus.provisional, NotificationPermission.allowed),
        (UNAuthorizationStatus.ephemeral, NotificationPermission.allowed)
    ])
    func systemStatusMapsToPermission(status: UNAuthorizationStatus, expected: NotificationPermission) {
        #expect(NotificationPermission(status) == expected)
    }

    // Напис «Сповіщення вимкнено» і кнопка «Відкрити Параметри» — лише при відмові.
    @Test(arguments: [
        (NotificationPermission.notDetermined, false),
        (NotificationPermission.denied, true),
        (NotificationPermission.allowed, false)
    ])
    func disabledNoticeOnlyWhenDenied(permission: NotificationPermission, shows: Bool) {
        #expect(permission.showsDisabledNotice == shows)
    }
}

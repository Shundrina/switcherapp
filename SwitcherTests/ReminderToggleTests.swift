import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import Switcher

// Дія «Перемкнути» в сповіщенні. `userInfo` несе UUID перемикача і його стан на момент планування
// (`ReminderPayload`). Дія ставить стан, ПРОТИЛЕЖНИЙ тому, що був при плануванні, а не інвертує
// поточний: якщо газ уже вимкнули в застосунку, «Перемкнути» на старому сповіщенні «газ горить»
// не має знову його вмикати.

private func fixedUUID(_ number: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", number))!
}

@MainActor
struct ReminderPayloadTests {
    @Test(arguments: [true, false])
    func payloadSurvivesUserInfoRoundTrip(wasOn: Bool) {
        let payload = ReminderPayload(switchID: fixedUUID(42), wasOn: wasOn)

        #expect(ReminderPayload(userInfo: payload.userInfo) == payload)
    }

    // Центр сповіщень зберігає userInfo як список властивостей: UUID туди не можна, лише рядок.
    @Test func userInfoIsPropertyListSerializable() {
        let payload = ReminderPayload(switchID: fixedUUID(42), wasOn: true)
        let dictionary = NSDictionary(dictionary: payload.userInfo)

        #expect(!payload.userInfo.isEmpty)
        #expect(PropertyListSerialization.propertyList(dictionary, isValidFor: .binary))
    }

    @Test func emptyUserInfoGivesNoPayload() {
        #expect(ReminderPayload(userInfo: [:]) == nil)
    }

    @Test func foreignUserInfoGivesNoPayload() {
        #expect(ReminderPayload(userInfo: ["aps": ["alert": "Інший застосунок"]]) == nil)
    }

    // Пошкоджене userInfo: ключі ті самі, а значення неправильні.
    @Test func malformedValuesGiveNoPayload() {
        let good = ReminderPayload(switchID: fixedUUID(42), wasOn: true).userInfo
        let broken = good.mapValues { _ in "не те" as Any }

        #expect(ReminderPayload(userInfo: broken) == nil)
    }
}

/// Категорія сповіщень із кнопкою «Перемкнути».
@MainActor
struct ReminderCategoryTests {
    @Test func categoryHasToggleAction() throws {
        let category = ReminderNotifications.category

        #expect(!ReminderNotifications.categoryID.isEmpty)
        #expect(!ReminderNotifications.toggleActionID.isEmpty)
        #expect(category.identifier == ReminderNotifications.categoryID)
        let action = try #require(category.actions.first)
        #expect(category.actions.count == 1)
        #expect(action.identifier == ReminderNotifications.toggleActionID)
        #expect(action.title == "Перемкнути")
    }

    // Кнопка спрацьовує без відкриття застосунку.
    @Test func toggleActionDoesNotOpenTheApp() throws {
        let action = try #require(ReminderNotifications.category.actions.first)

        #expect(!action.options.contains(.foreground))
    }
}

@MainActor
struct ReminderToggleActionTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let turnedOnAt = TestClock.date(day: 11, hour: 8, minute: 0)
    let actionAt = TestClock.date(day: 11, hour: 8, minute: 40)

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(_ name: String = "Газ горить", isOn: Bool) -> SwitchItem {
        let item = SwitchItem(name: name, createdAt: TestClock.date(day: 1, hour: 9, minute: 0))
        context.insert(item)
        if isOn {
            item.setOn(true, at: turnedOnAt)
        }
        return item
    }

    private func perform(_ payload: ReminderPayload) throws {
        try ReminderToggle.perform(userInfo: payload.userInfo, in: context, at: actionAt)
    }

    @Test func turnsOffSwitchThatWasOnWhenPlanned() throws {
        let gas = makeItem(isOn: true)

        try perform(ReminderPayload(switchID: gas.uuid, wasOn: true))

        #expect(gas.isOn == false)
        #expect(gas.lastToggledAt == actionAt)
        let event = try #require(gas.sortedEvents.first)
        #expect(gas.sortedEvents.count == 2)
        #expect(event.isOn == false)
        #expect(event.timestamp == actionAt)
    }

    @Test func turnsOnSwitchThatWasOffWhenPlanned() throws {
        let door = makeItem("Двері зачинені", isOn: false)

        try perform(ReminderPayload(switchID: door.uuid, wasOn: false))

        #expect(door.isOn == true)
        #expect(door.lastToggledAt == actionAt)
        #expect(door.sortedEvents.map(\.isOn) == [true])
        #expect(door.sortedEvents.map(\.timestamp) == [actionAt])
    }

    // Газ уже вимкнули в застосунку — старе сповіщення «увімкнено» не вмикає його знову.
    @Test func doesNotReverseStateAlreadyChangedInTheApp() throws {
        let gas = makeItem(isOn: true)
        let turnedOffInApp = TestClock.date(day: 11, hour: 8, minute: 35)
        gas.setOn(false, at: turnedOffInApp)

        try perform(ReminderPayload(switchID: gas.uuid, wasOn: true))

        #expect(gas.isOn == false)
        #expect(gas.lastToggledAt == turnedOffInApp)
        #expect(gas.sortedEvents.count == 2, "Зайва подія в історії")
    }

    @Test func touchesOnlyTheSwitchFromUserInfo() throws {
        let gas = makeItem("Газ горить", isOn: true)
        let iron = makeItem("Праска", isOn: true)

        try perform(ReminderPayload(switchID: gas.uuid, wasOn: true))

        #expect(gas.isOn == false)
        #expect(iron.isOn == true)
        #expect(iron.sortedEvents.count == 1)
    }

    // Перемикач видалили, а сповіщення лишилося: нічого не відбувається.
    @Test func deletedSwitchIsIgnored() throws {
        let gas = makeItem(isOn: true)
        let deleted = makeItem("Праска", isOn: true)
        let deletedID = deleted.uuid
        SwitchDeletion.delete(deleted, from: context)
        try context.save()

        try perform(ReminderPayload(switchID: deletedID, wasOn: true))

        #expect(gas.isOn == true)
        #expect(gas.sortedEvents.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<SwitchItem>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<SwitchEvent>()) == 1)
    }

    @Test func foreignUserInfoIsIgnored() throws {
        let gas = makeItem(isOn: true)

        try ReminderToggle.perform(userInfo: [:], in: context, at: actionAt)
        try ReminderToggle.perform(userInfo: ["aps": ["alert": "Інший застосунок"]], in: context, at: actionAt)

        #expect(gas.isOn == true)
        #expect(gas.sortedEvents.count == 1)
    }

    // Натиснули «Перемкнути» на двох повторах того самого нагадування — перемикання одне.
    @Test func secondTapOnSameReminderDoesNothing() throws {
        let gas = makeItem(isOn: true)
        let payload = ReminderPayload(switchID: gas.uuid, wasOn: true)

        try perform(payload)
        try ReminderToggle.perform(userInfo: payload.userInfo, in: context, at: TestClock.date(day: 11, hour: 8, minute: 50))

        #expect(gas.isOn == false)
        #expect(gas.lastToggledAt == actionAt)
        #expect(gas.sortedEvents.count == 2)
    }
}

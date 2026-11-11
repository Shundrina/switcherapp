import Foundation
import SwiftData
import Testing
@testable import Switcher

@MainActor
struct SwitcherTests {
    @Test func appModuleLoads() {
        _ = ContentView()
    }
}

@MainActor
struct SwitchItemTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func makeItem(name: String = "Полила квіти") -> SwitchItem {
        let item = SwitchItem(name: name)
        context.insert(item)
        return item
    }

    @Test func newItemIsOffWithEmptyHistory() {
        let item = makeItem()

        #expect(item.isOn == false)
        #expect(item.lastToggledAt == nil)
        #expect(item.sortedEvents.isEmpty)
    }

    @Test func turningOnRecordsEventWithTimestamp() throws {
        let item = makeItem()
        let date = Date(timeIntervalSince1970: 1_000)

        item.setOn(true, at: date)

        #expect(item.isOn)
        #expect(item.lastToggledAt == date)
        let event = try #require(item.sortedEvents.first)
        #expect(item.sortedEvents.count == 1)
        #expect(event.isOn)
        #expect(event.timestamp == date)
    }

    @Test func settingSameStateRecordsNothing() {
        let item = makeItem()

        item.setOn(false)

        #expect(item.lastToggledAt == nil)
        #expect(item.sortedEvents.isEmpty)
    }

    @Test func historyIsSortedNewestFirst() {
        let item = makeItem()
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 2_000)

        item.setOn(true, at: first)
        item.setOn(false, at: second)

        #expect(item.isOn == false)
        #expect(item.lastToggledAt == second)
        #expect(item.sortedEvents.map(\.timestamp) == [second, first])
        #expect(item.sortedEvents.map(\.isOn) == [false, true])
    }

    @Test func deletingItemDeletesItsEvents() throws {
        let item = makeItem()
        item.setOn(true)
        item.setOn(false)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<SwitchEvent>()) == 2)

        context.delete(item)
        try context.save()

        #expect(try context.fetchCount(FetchDescriptor<SwitchItem>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<SwitchEvent>()) == 0)
    }
}

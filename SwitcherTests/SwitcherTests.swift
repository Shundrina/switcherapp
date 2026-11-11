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

    @Test func newItemHasDefaultIconAndTone() {
        let item = makeItem()

        #expect(item.icon == .check)
        #expect(item.tone == .amber)
    }

    @Test func iconAndToneAreStoredAsRawValues() {
        let item = SwitchItem(name: "Газ горить", icon: .flame, tone: .coral)
        context.insert(item)
        #expect(item.iconRaw == "flame")
        #expect(item.toneRaw == "coral")

        item.icon = .lock
        item.tone = .sky

        #expect(item.iconRaw == "lock")
        #expect(item.toneRaw == "sky")
    }

    @Test func unknownStoredIconAndToneFallBackToDefaults() {
        let item = makeItem()

        item.iconRaw = "rocket"
        item.toneRaw = "neon"

        #expect(item.icon == .check)
        #expect(item.tone == .amber)
    }

    @Test func historyIsGroupedByDayNewestFirst() {
        let calendar = TestClock.calendar
        let item = makeItem()
        item.setOn(true, at: TestClock.date(day: 6, hour: 8, minute: 5))
        item.setOn(false, at: TestClock.date(day: 6, hour: 21, minute: 10))
        item.setOn(true, at: TestClock.date(day: 9, hour: 7, minute: 50))

        let days = item.historyDays(calendar: calendar)

        #expect(days.map(\.date) == [
            calendar.startOfDay(for: TestClock.date(day: 9, hour: 0, minute: 0)),
            calendar.startOfDay(for: TestClock.date(day: 6, hour: 0, minute: 0))
        ])
        #expect(days.map { $0.events.map(\.isOn) } == [[true], [false, true]])
    }

    @Test func itemWithoutEventsHasNoHistoryDays() {
        #expect(makeItem().historyDays().isEmpty)
    }
}

/// Фіксований календар і дати листопада 2026 року, щоб тести не залежали від часового поясу й сьогоднішнього дня.
enum TestClock {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv")!
        return calendar
    }

    static func date(day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
    }
}

@MainActor
struct SwitchFormattingTests {
    let calendar = TestClock.calendar
    let now = TestClock.date(day: 11, hour: 14, minute: 0)

    private func status(isOn: Bool, at date: Date?) -> String {
        SwitchFormatting.status(isOn: isOn, lastToggledAt: date, now: now, calendar: calendar)
    }

    @Test func statusForNeverToggledSwitch() {
        #expect(status(isOn: false, at: nil) == "Ще не перемикали")
    }

    @Test func statusForToday() {
        #expect(status(isOn: true, at: TestClock.date(day: 11, hour: 8, minute: 15)) == "Увімкнено сьогодні о 08:15")
    }

    @Test func statusForYesterday() {
        #expect(status(isOn: false, at: TestClock.date(day: 10, hour: 21, minute: 30)) == "Вимкнено вчора о 21:30")
    }

    @Test func statusForOlderDateNamesDayAndMonth() {
        #expect(status(isOn: false, at: TestClock.date(day: 6, hour: 21, minute: 10)) == "Вимкнено 6 листопада о 21:10")
    }

    @Test func statusUsesPrepositionObBeforeEleven() {
        #expect(status(isOn: true, at: TestClock.date(day: 11, hour: 11, minute: 5)) == "Увімкнено сьогодні об 11:05")
    }

    @Test func yesterdayIsDecidedByCalendarDayNotBy24Hours() {
        // 23:50 учора — це менш ніж доба тому, але вже не «сьогодні».
        let lateYesterday = TestClock.date(day: 10, hour: 23, minute: 50)
        let earlyToday = TestClock.date(day: 11, hour: 0, minute: 10)

        #expect(SwitchFormatting.dayPhrase(lateYesterday, now: earlyToday, calendar: calendar) == "вчора")
    }

    @Test func dayTitles() {
        #expect(SwitchFormatting.dayTitle(TestClock.date(day: 11, hour: 8, minute: 0), now: now, calendar: calendar) == "Сьогодні")
        #expect(SwitchFormatting.dayTitle(TestClock.date(day: 10, hour: 8, minute: 0), now: now, calendar: calendar) == "Вчора")
        #expect(SwitchFormatting.dayTitle(TestClock.date(day: 9, hour: 8, minute: 0), now: now, calendar: calendar) == "Понеділок, 9 листопада")
    }
}

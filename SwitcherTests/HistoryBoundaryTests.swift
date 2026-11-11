import Foundation
import SwiftData
import Testing
@testable import Switcher

@MainActor
struct HistoryDayBoundaryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    /// Календар задано явно: результат не залежить від поясу симулятора.
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Kyiv")!
        return calendar
    }()

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func date(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
    }

    private func makeItem(toggledAt dates: [Date]) -> SwitchItem {
        let item = SwitchItem(name: "Двері зачинені")
        context.insert(item)
        for (index, date) in dates.enumerated() {
            item.setOn(index.isMultiple(of: 2), at: date)
        }
        return item
    }

    @Test func eventsAroundMidnightLandInDifferentDays() {
        let beforeMidnight = date(month: 11, day: 9, hour: 23, minute: 59)
        let afterMidnight = date(month: 11, day: 10, hour: 0, minute: 1)
        let item = makeItem(toggledAt: [beforeMidnight, afterMidnight])

        let days = item.historyDays(calendar: calendar)

        #expect(days.map(\.date) == [
            date(month: 11, day: 10, hour: 0, minute: 0),
            date(month: 11, day: 9, hour: 0, minute: 0)
        ])
        #expect(days.map { $0.events.map(\.timestamp) } == [[afterMidnight], [beforeMidnight]])
    }

    // 25.10.2026 у Києві о 04:00 годинник переводять на 03:00: доба триває 25 годин.
    @Test func dstFallBackDayIsSingleDay() throws {
        let dates = [
            date(month: 10, day: 24, hour: 23, minute: 59),
            date(month: 10, day: 25, hour: 0, minute: 1),
            date(month: 10, day: 25, hour: 2, minute: 30),
            date(month: 10, day: 25, hour: 12, minute: 0),
            date(month: 10, day: 25, hour: 23, minute: 59),
            date(month: 10, day: 26, hour: 0, minute: 1)
        ]
        let item = makeItem(toggledAt: dates)

        let days = item.historyDays(calendar: calendar)

        let dayStarts = [26, 25, 24].map { date(month: 10, day: $0, hour: 0, minute: 0) }
        #expect(days.map(\.date) == dayStarts)
        #expect(days.map(\.events.count) == [1, 4, 1])

        let transitionDay = try #require(days.dropFirst().first)
        #expect(transitionDay.events.map(\.timestamp) == Array(dates[1...4].reversed()))
        // Перевірка самого календаря: між початками 25 і 26 жовтня — 25 годин.
        #expect(dayStarts[0].timeIntervalSince(dayStarts[1]) == 25 * 3600)
    }

    // Подія в «повторену» годину 03:00–04:00 (вже за зимовим часом) — той самий день.
    @Test func eventInRepeatedHourBelongsToTransitionDay() throws {
        // 03:30 EEST (UTC+3) = 00:30 UTC; 03:30 EET (UTC+2) = 01:30 UTC.
        let firstPass = Date(timeIntervalSince1970: 1_792_888_200)  // 2026-10-25 00:30 UTC
        let secondPass = Date(timeIntervalSince1970: 1_792_891_800) // 2026-10-25 01:30 UTC
        let item = makeItem(toggledAt: [firstPass, secondPass])

        let days = item.historyDays(calendar: calendar)

        let day = try #require(days.first)
        #expect(days.count == 1)
        #expect(day.date == date(month: 10, day: 25, hour: 0, minute: 0))
        #expect(SwitchFormatting.time(firstPass, calendar: calendar) == "03:30")
        #expect(SwitchFormatting.time(secondPass, calendar: calendar) == "03:30")
    }

    @Test func sameInstantGroupsDifferentlyInDifferentTimeZones() {
        // 2026-11-09 22:30 UTC: у Києві вже 10 листопада, у Лондоні ще 9-те.
        let instant = Date(timeIntervalSince1970: 1_794_263_400)
        let item = makeItem(toggledAt: [instant])
        var london = Calendar(identifier: .gregorian)
        london.timeZone = TimeZone(identifier: "Europe/London")!

        let kyivDay = item.historyDays(calendar: calendar).first?.date
        let londonDay = item.historyDays(calendar: london).first?.date

        #expect(kyivDay.map { calendar.component(.day, from: $0) } == 10)
        #expect(londonDay.map { london.component(.day, from: $0) } == 9)
    }
}

@MainActor
struct SwitchFormattingTimeTests {
    let calendar = TestClock.calendar
    let now = TestClock.date(day: 11, hour: 14, minute: 0)

    @Test(arguments: [
        (7, 5, "07:05"),
        (0, 0, "00:00"),
        (0, 1, "00:01"),
        (9, 0, "09:00"),
        (23, 59, "23:59")
    ])
    func timeIsZeroPadded(hour: Int, minute: Int, expected: String) {
        #expect(SwitchFormatting.time(TestClock.date(day: 11, hour: hour, minute: minute), calendar: calendar) == expected)
    }

    @Test(arguments: [
        (10, 59, "о 10:59"),
        (11, 0, "об 11:00"),
        (11, 59, "об 11:59"),
        (12, 0, "о 12:00"),
        (0, 0, "о 00:00"),
        (23, 0, "о 23:00")
    ])
    func prepositionBoundaries(hour: Int, minute: Int, expected: String) {
        let status = SwitchFormatting.status(
            isOn: true,
            lastToggledAt: TestClock.date(day: 11, hour: hour, minute: minute),
            now: now,
            calendar: calendar
        )
        #expect(status == "Увімкнено сьогодні \(expected)")
    }
}

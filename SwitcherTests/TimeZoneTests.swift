import Combine
import Foundation
import SwiftData
import Testing
import UIKit
@testable import Switcher

/// Календар з явним поясом: результат не залежить від поясу симулятора.
private func calendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

/// Мить, задана годинником у поясі `zone` (лише для годин, які в цьому поясі існують і не повторюються).
private func local(_ zone: String, _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    calendar(zone).date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
}

/// Мить за UTC — для «того самого моменту» в різних поясах і для годин навколо переведення годинника.
private func utc(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
    local("UTC", year, month, day, hour, minute)
}

// MARK: - Перехід на літній час

/// 29.03.2026 у Києві о 03:00 (EET, UTC+2) годинник переводять на 04:00 (EEST, UTC+3):
/// доба триває 23 години, місцевих 03:00–03:59 цього дня немає.
@MainActor
struct SpringForwardHistoryTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }
    let kyiv = calendar("Europe/Kyiv")

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func kyivDate(month: Int, day: Int, hour: Int, minute: Int) -> Date {
        local("Europe/Kyiv", 2026, month, day, hour, minute)
    }

    private func makeItem(toggledAt dates: [Date]) -> SwitchItem {
        let item = SwitchItem(name: "Двері зачинені")
        context.insert(item)
        for (index, date) in dates.enumerated() {
            item.setOn(index.isMultiple(of: 2), at: date)
        }
        return item
    }

    @Test func springForwardDayIsSingleShortDay() throws {
        let dates = [
            kyivDate(month: 3, day: 28, hour: 23, minute: 59),
            kyivDate(month: 3, day: 29, hour: 0, minute: 1),
            kyivDate(month: 3, day: 29, hour: 2, minute: 59),
            kyivDate(month: 3, day: 29, hour: 4, minute: 0),
            kyivDate(month: 3, day: 29, hour: 12, minute: 0),
            kyivDate(month: 3, day: 29, hour: 23, minute: 59),
            kyivDate(month: 3, day: 30, hour: 0, minute: 1)
        ]
        let item = makeItem(toggledAt: dates)

        let days = item.historyDays(calendar: kyiv)

        let dayStarts = [30, 29, 28].map { kyivDate(month: 3, day: $0, hour: 0, minute: 0) }
        #expect(days.map(\.date) == dayStarts)
        #expect(days.map(\.events.count) == [1, 5, 1])

        let transitionDay = try #require(days.dropFirst().first)
        #expect(transitionDay.events.map(\.timestamp) == Array(dates[1...5].reversed()))
        // Перевірка самого календаря: між початками 29 і 30 березня — 23 години.
        #expect(dayStarts[0].timeIntervalSince(dayStarts[1]) == 23 * 3600)
    }

    // 02:59 за зимовим і 04:00 за літнім часом — сусідні хвилини, обидві 29 березня.
    @Test func eventsAcrossTheGapKeepWallClockTime() throws {
        let beforeGap = utc(2026, 3, 29, 0, 59) // 02:59 EET
        let afterGap = utc(2026, 3, 29, 1, 0)   // 04:00 EEST
        let item = makeItem(toggledAt: [beforeGap, afterGap])

        let days = item.historyDays(calendar: kyiv)

        let day = try #require(days.first)
        #expect(days.count == 1)
        #expect(day.date == kyivDate(month: 3, day: 29, hour: 0, minute: 0))
        #expect(day.events.map(\.timestamp) == [afterGap, beforeGap])
        #expect(SwitchFormatting.time(beforeGap, calendar: kyiv) == "02:59")
        #expect(SwitchFormatting.time(afterGap, calendar: kyiv) == "04:00")
    }

    @Test func statusOnSpringForwardDay() {
        let now = kyivDate(month: 3, day: 29, hour: 4, minute: 30)

        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: utc(2026, 3, 29, 0, 59), now: now, calendar: kyiv)
            == "Увімкнено сьогодні о 02:59")
        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: utc(2026, 3, 29, 1, 0), now: now, calendar: kyiv)
            == "Увімкнено сьогодні о 04:00")
        #expect(SwitchFormatting.status(isOn: false, lastToggledAt: kyivDate(month: 3, day: 28, hour: 23, minute: 59), now: now, calendar: kyiv)
            == "Вимкнено вчора о 23:59")
    }

    // Наступного дня після переходу: «вчора» — за календарним днем, а не «менше 24 годин тому».
    @Test func dayAfterSpringForwardUsesCalendarDays() {
        let now = kyivDate(month: 3, day: 30, hour: 0, minute: 10)
        // 28.03 23:55 — лише 23 год 15 хв тому, але це вже позавчора.
        let twoDaysAgo = kyivDate(month: 3, day: 28, hour: 23, minute: 55)
        let yesterday = kyivDate(month: 3, day: 29, hour: 0, minute: 5)

        #expect(now.timeIntervalSince(twoDaysAgo) < 24 * 3600)
        #expect(SwitchFormatting.status(isOn: false, lastToggledAt: twoDaysAgo, now: now, calendar: kyiv)
            == "Вимкнено 28 березня о 23:55")
        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: yesterday, now: now, calendar: kyiv)
            == "Увімкнено вчора о 00:05")
    }

    // 30.03 о 03:30 — година, якої напередодні не було; «вчора» все одно 29 березня.
    @Test func yesterdayFromHourThatDidNotExistTheDayBefore() {
        let now = kyivDate(month: 3, day: 30, hour: 3, minute: 30)

        #expect(SwitchFormatting.dayPhrase(utc(2026, 3, 29, 0, 30), now: now, calendar: kyiv) == "вчора")  // 02:30 EET
        #expect(SwitchFormatting.dayPhrase(utc(2026, 3, 29, 1, 30), now: now, calendar: kyiv) == "вчора")  // 04:30 EEST
        #expect(SwitchFormatting.dayPhrase(kyivDate(month: 3, day: 28, hour: 23, minute: 59), now: now, calendar: kyiv) == "28 березня")
    }

    @Test func dayTitlesAfterSpringForward() {
        let dates = [
            kyivDate(month: 3, day: 28, hour: 22, minute: 0),
            kyivDate(month: 3, day: 29, hour: 2, minute: 59),
            kyivDate(month: 3, day: 30, hour: 0, minute: 5)
        ]
        let item = makeItem(toggledAt: dates)
        let now = kyivDate(month: 3, day: 30, hour: 0, minute: 10)

        let titles = item.historyDays(calendar: kyiv).map {
            SwitchFormatting.dayTitle($0.date, now: now, calendar: kyiv)
        }

        #expect(titles == ["Сьогодні", "Вчора", "Субота, 28 березня"])
    }
}

// MARK: - «Сьогодні/вчора» біля півночі в різних поясах

/// Той самий момент у різних поясах — різні дні: тексти рахуються в поясі переданого календаря.
@MainActor
struct DayPhraseAcrossTimeZonesTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: SwitchItem.self, configurations: configuration)
    }

    private func dayTitles(eventsAt dates: [Date], now: Date, zone: String) -> [String] {
        let item = SwitchItem(name: "Газ горить")
        context.insert(item)
        for (index, date) in dates.enumerated() {
            item.setOn(index.isMultiple(of: 2), at: date)
        }
        let zoneCalendar = calendar(zone)
        return item.historyDays(calendar: zoneCalendar).map {
            SwitchFormatting.dayTitle($0.date, now: now, calendar: zoneCalendar)
        }
    }

    // Подія 09.11 23:00 UTC, зараз 10.11 06:00 UTC.
    @Test(arguments: [
        ("Europe/Kyiv", "Увімкнено сьогодні о 01:00", "Сьогодні"),
        ("Asia/Tokyo", "Увімкнено сьогодні о 08:00", "Сьогодні"),
        ("Europe/London", "Увімкнено вчора о 23:00", "Вчора"),
        ("America/New_York", "Увімкнено вчора о 18:00", "Вчора")
    ])
    func eastOfMidnightIsTodayWestIsYesterday(zone: String, status: String, title: String) {
        let event = utc(2026, 11, 9, 23, 0)
        let now = utc(2026, 11, 10, 6, 0)

        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: event, now: now, calendar: calendar(zone)) == status)
        #expect(dayTitles(eventsAt: [event], now: now, zone: zone) == [title])
    }

    // Подія 09.11 21:30 UTC, зараз 09.11 22:30 UTC: у Києві між ними північ, у Нью-Йорку — ні.
    @Test(arguments: [
        ("Europe/Kyiv", "Вимкнено вчора о 23:30", "Вчора"),
        ("America/New_York", "Вимкнено сьогодні о 16:30", "Сьогодні"),
        ("Asia/Tokyo", "Вимкнено сьогодні о 06:30", "Сьогодні")
    ])
    func midnightBetweenEventAndNowOnlyInSomeZones(zone: String, status: String, title: String) {
        let event = utc(2026, 11, 9, 21, 30)
        let now = utc(2026, 11, 9, 22, 30)

        #expect(SwitchFormatting.status(isOn: false, lastToggledAt: event, now: now, calendar: calendar(zone)) == status)
        #expect(dayTitles(eventsAt: [event], now: now, zone: zone) == [title])
    }

    // Подія 08.11 23:30 UTC, зараз 10.11 14:00 UTC: у Нью-Йорку це вже позавчора.
    @Test(arguments: [
        ("America/New_York", "Увімкнено 8 листопада о 18:30", "Неділя, 8 листопада"),
        ("Europe/Kyiv", "Увімкнено вчора о 01:30", "Вчора"),
        ("Asia/Tokyo", "Увімкнено вчора о 08:30", "Вчора")
    ])
    func olderDayNamedInLocalZone(zone: String, status: String, title: String) {
        let event = utc(2026, 11, 8, 23, 30)
        let now = utc(2026, 11, 10, 14, 0)

        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: event, now: now, calendar: calendar(zone)) == status)
        #expect(dayTitles(eventsAt: [event], now: now, zone: zone) == [title])
    }

    // 08.03.2026 у Нью-Йорку о 02:00 (EST) годинник переводять на 03:00 (EDT); у Києві звичайний день.
    // Подія 08.03 06:30 UTC (01:30 EST, 08:30 у Києві), зараз 08.03 22:30 UTC (18:30 EDT, 00:30 9 березня в Києві).
    @Test(arguments: [
        ("America/New_York", "Увімкнено сьогодні о 01:30", "Сьогодні"),
        ("Europe/Kyiv", "Увімкнено вчора о 08:30", "Вчора")
    ])
    func newYorkSpringForwardDay(zone: String, status: String, title: String) {
        let event = utc(2026, 3, 8, 6, 30)
        let now = utc(2026, 3, 8, 22, 30)

        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: event, now: now, calendar: calendar(zone)) == status)
        #expect(dayTitles(eventsAt: [event], now: now, zone: zone) == [title])
    }

    // Наступного дня після переходу в Нью-Йорку: 23 год 45 хв тому — уже позавчора.
    // Подія 08.03 04:45 UTC (7 березня 23:45 EST), зараз 09.03 04:30 UTC (9 березня 00:30 EDT).
    @Test(arguments: [
        ("America/New_York", "Вимкнено 7 березня о 23:45", "Субота, 7 березня"),
        ("Europe/Kyiv", "Вимкнено вчора о 06:45", "Вчора")
    ])
    func dayAfterNewYorkSpringForward(zone: String, status: String, title: String) {
        let event = utc(2026, 3, 8, 4, 45)
        let now = utc(2026, 3, 9, 4, 30)

        #expect(now.timeIntervalSince(event) < 24 * 3600)
        #expect(SwitchFormatting.status(isOn: false, lastToggledAt: event, now: now, calendar: calendar(zone)) == status)
        #expect(dayTitles(eventsAt: [event], now: now, zone: zone) == [title])
    }

    // 01.11.2026 у Нью-Йорку о 02:00 (EDT) годинник переводять на 01:00 (EST): доба — 25 годин.
    // Пізно ввечері цієї доби «24 години тому» — ще вона сама, а вчорашня подія — понад 24 години тому.
    // Подія 01.11 03:00 UTC (31 жовтня 23:00 EDT), зараз 02.11 04:30 UTC (1 листопада 23:30 EST).
    @Test func lateOnNewYorkFallBackDayYesterdayIsMoreThan24HoursAgo() {
        let newYork = calendar("America/New_York")
        let event = utc(2026, 11, 1, 3, 0)
        let now = utc(2026, 11, 2, 4, 30)

        #expect(now.timeIntervalSince(event) > 24 * 3600)
        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: event, now: now, calendar: newYork)
            == "Увімкнено вчора о 23:00")
        #expect(dayTitles(eventsAt: [event], now: now, zone: "America/New_York") == ["Вчора"])
    }

    // Те саме для Києва: 25.10.2026 триває 25 годин. Подія 24.10 23:00 EEST (20:00 UTC),
    // зараз 25.10 23:30 EET (21:30 UTC).
    @Test func lateOnKyivFallBackDayYesterdayIsMoreThan24HoursAgo() {
        let kyiv = calendar("Europe/Kyiv")
        let event = utc(2026, 10, 24, 20, 0)
        let now = utc(2026, 10, 25, 21, 30)

        #expect(now.timeIntervalSince(event) > 24 * 3600)
        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: event, now: now, calendar: kyiv)
            == "Увімкнено вчора о 23:00")
        #expect(dayTitles(eventsAt: [event], now: now, zone: "Europe/Kyiv") == ["Вчора"])
    }

    // У «повторену» годину в Києві: подія в 03:15 до переведення, зараз 03:30 після — «сьогодні».
    @Test func repeatedHourInKyivIsToday() {
        let kyiv = calendar("Europe/Kyiv")
        let event = utc(2026, 10, 25, 0, 15) // 03:15 EEST
        let now = utc(2026, 10, 25, 1, 30)   // 03:30 EET

        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: event, now: now, calendar: kyiv)
            == "Увімкнено сьогодні о 03:15")
    }

    // Гавана 08.03.2026: годинник переводять з 00:00 на 01:00 — північ пропущено, доба починається о 01:00.
    @Test func dayStartingAtOneAmWhenMidnightIsSkipped() throws {
        let havana = calendar("America/Havana")
        let lateEvening = utc(2026, 3, 8, 4, 30)    // 7 березня 23:30 CST
        let firstMinute = utc(2026, 3, 8, 5, 0)     // 8 березня 01:00 CDT
        let item = SwitchItem(name: "Газ горить")
        context.insert(item)
        item.setOn(true, at: lateEvening)
        item.setOn(false, at: firstMinute)

        let days = item.historyDays(calendar: havana)

        #expect(days.map(\.date) == [firstMinute, local("America/Havana", 2026, 3, 7, 0, 0)])
        #expect(days.map { $0.events.map(\.timestamp) } == [[firstMinute], [lateEvening]])
        #expect(SwitchFormatting.time(lateEvening, calendar: havana) == "23:30")
        #expect(SwitchFormatting.time(firstMinute, calendar: havana) == "01:00")

        let tenPastOne = utc(2026, 3, 8, 5, 10)      // 8 березня 01:10 CDT
        #expect(SwitchFormatting.status(isOn: true, lastToggledAt: lateEvening, now: tenPastOne, calendar: havana)
            == "Увімкнено вчора о 23:30")
        let halfPastMidnightNextDay = utc(2026, 3, 9, 4, 30) // 9 березня 00:30 CDT
        #expect(SwitchFormatting.status(isOn: false, lastToggledAt: firstMinute, now: halfPastMidnightNextDay, calendar: havana)
            == "Вимкнено вчора о 01:00")
        let titles = days.map { SwitchFormatting.dayTitle($0.date, now: halfPastMidnightNextDay, calendar: havana) }
        #expect(titles == ["Вчора", "Субота, 7 березня"])
    }
}

// MARK: - Оновлення поточної миті, поки застосунок відкритий

/// Поточна мить (`\.now`) має оновлюватися не лише опівночі й при поверненні з фону, а й коли
/// змінюється системний пояс або системний час. Сповіщення, на які реагує `CurrentDateModifier`,
/// зібрано в один видавець `CurrentDateRefresh.publisher(center:)`; тут він підписаний
/// на окремий `NotificationCenter`, щоб системні сповіщення тестові не заважали.
@MainActor
struct CurrentDateRefreshTests {
    let center = NotificationCenter()

    /// Публікує `names` по черзі й повертає, скільки разів спрацював видавець, коли спрацювання
    /// очікуваних `expected` разів дочекалися (або минуло 2 с). Видавець може доставляти
    /// асинхронно (через головну чергу), тому лічильник перевіряється з очікуванням, без фіксованих пауз.
    private func refreshCount(posting names: [Notification.Name], expected: Int) async throws -> Int {
        var count = 0
        let subscription = CurrentDateRefresh.publisher(center: center).sink { _ in count += 1 }
        defer { subscription.cancel() }

        for name in names {
            center.post(name: name, object: nil)
        }
        let deadline = Date.now.addingTimeInterval(2)
        while count < expected, Date.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        // Сповіщення, які прийшли б із запізненням, — у тій самій черзі після очікуваних.
        await Task.yield()
        return count
    }

    @Test func refreshesWhenSystemTimeZoneChanges() async throws {
        #expect(try await refreshCount(posting: [.NSSystemTimeZoneDidChange], expected: 1) == 1)
    }

    @Test func refreshesOnSignificantTimeChange() async throws {
        #expect(try await refreshCount(posting: [UIApplication.significantTimeChangeNotification], expected: 1) == 1)
    }

    @Test func stillRefreshesWhenCalendarDayChanges() async throws {
        #expect(try await refreshCount(posting: [.NSCalendarDayChanged], expected: 1) == 1)
    }

    // Стороннє сповіщення не оновлює; кожне з потрібних — оновлює.
    @Test func refreshesOnlyOnRelevantNotifications() async throws {
        let names: [Notification.Name] = [
            UIApplication.didReceiveMemoryWarningNotification,
            .NSSystemTimeZoneDidChange,
            Notification.Name("SwitcherTests.unrelated"),
            UIApplication.significantTimeChangeNotification,
            .NSCalendarDayChanged
        ]

        #expect(try await refreshCount(posting: names, expected: 3) == 3)
    }

    // Повторна зміна поясу — повторне оновлення.
    @Test func everyTimeZoneChangeRefreshes() async throws {
        let names: [Notification.Name] = [.NSSystemTimeZoneDidChange, .NSSystemTimeZoneDidChange]

        #expect(try await refreshCount(posting: names, expected: 2) == 2)
    }
}

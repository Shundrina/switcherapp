import XCTest

/// Застосунок показує час у поясі, у якому його запущено. Пояс задається змінною середовища `TZ`
/// процесу застосунку; очікуваний час тест рахує сам через `TimeZone(identifier:)`.
/// Зміну поясу, поки застосунок відкритий, XCUITest не відтворює — це перевірка вручну на iPhone.
final class TimeZoneUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Нью-Йорк (UTC−5/−4) — пояс, далекий від поясу симулятора.
    @MainActor
    func testStatusAndHistoryShowNewYorkTime() throws {
        try checkToggleTimeIsShown(inTimeZone: "America/New_York")
    }

    /// Токіо (UTC+9, без переведення годинника) — з іншого боку від поясу симулятора.
    @MainActor
    func testStatusAndHistoryShowTokyoTime() throws {
        try checkToggleTimeIsShown(inTimeZone: "Asia/Tokyo")
    }

    /// Запуск у поясі `identifier` → додати перемикач → увімкнути в списку → час у статусі картки
    /// й у записі історії — за цим поясом.
    @MainActor
    private func checkToggleTimeIsShown(inTimeZone identifier: String, file: StaticString = #filePath, line: UInt = #line) throws {
        let zone = try XCTUnwrap(TimeZone(identifier: identifier), "Невідомий пояс \(identifier)", file: file, line: line)
        let app = XCUIApplication.launchedForTesting(environment: ["TZ": identifier])
        let name = "Двері зачинені"
        let row = app.addSwitch(named: name, file: file, line: line)

        let toggle = row.switches[AccessibilityID.switchRowToggle]
        XCTAssertTrue(toggle.waitForExistence(timeout: uiTimeout), "Немає перемикача в рядку", file: file, line: line)
        let before = Date()
        toggle.tap()
        XCTAssertTrue(waitForValue("1", of: toggle), "Перемикач у рядку не увімкнувся", file: file, line: line)
        let after = Date()

        // Перемикання могло припасти на межу хвилини — годиться будь-яка хвилина між `before` і `after`.
        let expected = minuteTexts(from: before, to: after, in: zone)
        // Той самий проміжок у поясі процесу тестів (симулятора): якщо показано його, `TZ` не врахувався.
        let simulatorZone = TimeZone.current
        let simulatorTimes = minuteTexts(from: before, to: after, in: simulatorZone)
            .subtracting(expected)

        let openButton = row.buttons[AccessibilityID.switchRowOpenButton]
        XCTAssertTrue(openButton.waitForExistence(timeout: uiTimeout), "Немає кнопки відкриття в рядку", file: file, line: line)
        let status = openButton.label
        XCTAssertTrue(
            expected.contains { status.hasSuffix(" \($0)") },
            "Статус картки «\(status)» має закінчуватися часом за \(identifier): \(expected.sorted())"
                + (simulatorTimes.contains { status.contains($0) } ? " — показано час поясу симулятора \(simulatorZone.identifier)" : ""),
            file: file, line: line
        )

        app.openSwitch(named: name, file: file, line: line)
        let event = app.descendants(matching: .any).matching(identifier: AccessibilityID.historyEvent).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: uiTimeout), "В історії немає запису", file: file, line: line)
        XCTAssertTrue(
            expected.contains { event.label.contains($0) },
            "Запис історії «\(event.label)» має містити час за \(identifier): \(expected.sorted())"
                + (simulatorTimes.contains { event.label.contains($0) } ? " — показано час поясу симулятора \(simulatorZone.identifier)" : ""),
            file: file, line: line
        )
    }

    /// Тексти «HH:mm» для кожної хвилини від `start` до `end` у поясі `zone`.
    private func minuteTexts(from start: Date, to end: Date, in zone: TimeZone) -> Set<String> {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        var texts: Set<String> = []
        var moment = start
        while moment <= end {
            let parts = calendar.dateComponents([.hour, .minute], from: moment)
            texts.insert(String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0))
            moment.addTimeInterval(60)
        }
        let last = calendar.dateComponents([.hour, .minute], from: end)
        texts.insert(String(format: "%02d:%02d", last.hour ?? 0, last.minute ?? 0))
        return texts
    }
}

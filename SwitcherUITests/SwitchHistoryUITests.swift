import XCTest

/// Перемикання в списку записується в історію на екрані перемикача.
final class SwitchHistoryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Новий перемикач без історії → увімкнути в списку → на його екрані один запис «Увімкнено».
    @MainActor
    func testTogglingInListAddsHistoryEntry() throws {
        let app = XCUIApplication.launchedForTesting()
        let row = app.addSwitch(named: "Двері зачинені")
        let events = app.descendants(matching: .any).matching(identifier: AccessibilityID.historyEvent)

        // До перемикання історія порожня.
        app.openSwitch(named: "Двері зачинені")
        XCTAssertTrue(
            app.staticTexts[AccessibilityID.historyEmptyText].waitForExistence(timeout: uiTimeout),
            "Нема тексту порожньої історії"
        )
        XCTAssertEqual(events.count, 0, "Історія нового перемикача не порожня")
        app.goBackToList()

        let toggle = row.switches[AccessibilityID.switchRowToggle]
        XCTAssertTrue(toggle.waitForExistence(timeout: uiTimeout), "Немає перемикача в рядку")
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.tap()
        XCTAssertTrue(waitForValue("1", of: toggle), "Перемикач у рядку не увімкнувся")

        app.openSwitch(named: "Двері зачинені")
        XCTAssertTrue(events.firstMatch.waitForExistence(timeout: uiTimeout), "В історії немає запису")
        XCTAssertEqual(events.count, 1, "Одне перемикання — один запис")
        XCTAssertTrue(
            events.firstMatch.label.hasPrefix("Увімкнено"),
            "Запис має бути «Увімкнено», а не «\(events.firstMatch.label)»"
        )
        XCTAssertFalse(app.staticTexts[AccessibilityID.historyEmptyText].exists, "Текст порожньої історії лишився")
    }
}

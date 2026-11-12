import XCTest

/// Видалення перемикача свайпом ліворуч у списку з підтвердженням.
final class SwitchDeletionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Свайп → «Видалити» → підтвердження «Видалити «назва»?» → «Видалити»: рядка більше немає.
    @MainActor
    func testSwipeDeleteAndConfirmRemovesRow() throws {
        let app = XCUIApplication.launchedForTesting()
        let row = app.addSwitch(named: "Полила квіти")

        let alert = showDeletionConfirmation(for: row, named: "Полила квіти", in: app)
        alert.buttons["Видалити"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: uiTimeout), "Вікно підтвердження не зникло")
        XCTAssertTrue(row.waitForNonExistence(timeout: uiTimeout), "Рядок лишився в списку після підтвердження")
    }

    /// Свайп → «Видалити» → «Скасувати»: вікно зникає, рядок лишається.
    @MainActor
    func testSwipeDeleteAndCancelKeepsRow() throws {
        let app = XCUIApplication.launchedForTesting()
        let row = app.addSwitch(named: "Двері зачинені")

        let alert = showDeletionConfirmation(for: row, named: "Двері зачинені", in: app)
        alert.buttons["Скасувати"].tap()

        XCTAssertTrue(alert.waitForNonExistence(timeout: uiTimeout), "Вікно підтвердження не зникло")
        // Рядок не має зникнути й згодом: даємо час на можливу анімацію видалення.
        XCTAssertFalse(row.waitForNonExistence(timeout: 3), "Рядок зник після «Скасувати»")
        XCTAssertTrue(row.exists)
    }

    /// Свайпає рядок ліворуч, натискає «Видалити» і повертає вікно підтвердження.
    @MainActor
    private func showDeletionConfirmation(for row: XCUIElement, named name: String, in app: XCUIApplication) -> XCUIElement {
        row.revealTrailingSwipeActions()
        // Кнопку дії свайпу запит, обмежений коміркою, не знаходить — шукаємо від застосунку.
        // Інших кнопок «Видалити» на екрані списку немає.
        let deleteAction = app.buttons["Видалити"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: uiTimeout), "Після свайпу немає кнопки «Видалити»")
        deleteAction.tap()

        let alert = app.alerts["Видалити «\(name)»?"]
        XCTAssertTrue(alert.waitForExistence(timeout: uiTimeout), "Немає вікна «Видалити «\(name)»?»")
        // Свайп сам по собі нічого не видаляє: поки вікно відкрите, рядок на місці.
        XCTAssertTrue(row.exists, "Рядок зник ще до підтвердження")
        return alert
    }
}

import XCTest

/// Межа назви — 30 символів: у повне поле нові символи не вводяться, лічильник показує «30 / 30».
final class SwitchNameLimitUITests: XCTestCase {
    /// 35 різних символів без пробілів (щоб автовиправлення клавіатури нічого не замінювало).
    private let typed35 = "0123456789АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФ"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCTAssertEqual(typed35.count, 35)
    }

    /// Екран додавання: ввести 35 символів → у полі перші 30, лічильник «Символів: 30 з 30».
    @MainActor
    func testAddFieldStopsAt30Characters() throws {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку")
        app.addSwitchButton.tap()

        let field = app.textFields[AccessibilityID.addSwitchNameField]
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання")
        field.tap()
        field.typeText(typed35)

        XCTAssertEqual(field.value as? String, String(typed35.prefix(30)))
        let counter = app.staticTexts[AccessibilityID.addSwitchNameCounter]
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(counter.label, "Символів: 30 з 30")
    }

    /// Екран перемикача: стерти назву, ввести 35 символів → у полі перші 30, лічильник «Символів: 30 з 30».
    @MainActor
    func testRenameFieldStopsAt30Characters() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")
        app.buttons[AccessibilityID.switchNameButton].tap()

        let field = app.textFields[AccessibilityID.switchNameEditField]
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля редагування назви")
        field.clearText()
        field.typeText(typed35)

        XCTAssertEqual(field.value as? String, String(typed35.prefix(30)))
        let counter = app.staticTexts[AccessibilityID.switchNameEditCounter]
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(counter.label, "Символів: 30 з 30")
    }
}

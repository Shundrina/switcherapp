import XCTest

/// Перейменування перемикача на його екрані: натискання на назву відкриває поле на тому самому місці.
final class SwitchRenameUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Назва → поле → стерти, ввести нову, завершити переносом рядка («Готово») →
    /// нова назва на екрані перемикача і в списку.
    @MainActor
    func testRenameInPlaceUpdatesSwitchScreenAndList() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Газ горить")
        app.openSwitch(named: "Газ горить")

        let nameButton = app.buttons[AccessibilityID.switchNameButton]
        XCTAssertEqual(nameButton.label, "Газ горить")
        nameButton.tap()

        let field = app.textFields[AccessibilityID.switchNameEditField]
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на назву не відкрило поле редагування")
        XCTAssertEqual(field.value as? String, "Газ горить", "Поле має містити поточну назву")
        field.clearText()
        // Перенос рядка — це «Готово» в багаторядковому полі; працює і з апаратною клавіатурою.
        field.typeText("Газ вимкнено\n")

        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "Поле редагування не закрилося після «Готово»")
        XCTAssertTrue(nameButton.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(nameButton.label, "Газ вимкнено", "На екрані перемикача стара назва")

        app.goBackToList()
        XCTAssertTrue(app.row(named: "Газ вимкнено").waitForExistence(timeout: uiTimeout), "У списку немає нової назви")
        XCTAssertFalse(app.row(named: "Газ горить").exists, "У списку лишилася стара назва")
    }
}

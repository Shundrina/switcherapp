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

        let field = app.switchNameEditField
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

    /// Назва → поле → нова назва без «Готово» → прокрутити екран пальцем над екранною клавіатурою
    /// (`scrollDismissesKeyboard`) → поле закрилося, нова назва на екрані перемикача і в списку.
    @MainActor
    func testScrollingEndsRenameAndSavesName() throws {
        let app = XCUIApplication.launchedForTesting()
        let (nameButton, field) = startRenaming(in: app, from: "Газ горить", to: "Газ вимкнено")

        app.scrollSwitchScreenUpAboveKeyboard()

        assertRenamed(in: app, nameButton: nameButton, field: field, from: "Газ горить", to: "Газ вимкнено", after: "прокрутки")
    }

    /// Назва → поле → нова назва без «Готово» → обрати інший колір → колір обрано,
    /// поле закрилося, нова назва на екрані перемикача і в списку.
    @MainActor
    func testChoosingColorEndsRenameAndSavesName() throws {
        let app = XCUIApplication.launchedForTesting()
        let (nameButton, field) = startRenaming(in: app, from: "Газ горить", to: "Газ вимкнено")

        // Новий перемикач — бурштиновий (`amber`); «Корал» — інший колір.
        let coral = app.buttons[AccessibilityID.toneOption("coral")]
        XCTAssertTrue(coral.waitForExistence(timeout: uiTimeout), "Немає кнопки кольору «Корал»")
        XCTAssertFalse(coral.isSelected, "«Корал» уже обрано — тест не перевірить зміну кольору")
        coral.tap()

        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: coral)
        XCTAssertEqual(XCTWaiter().wait(for: [selected], timeout: uiTimeout), .completed, "Натискання не обрало колір")
        assertRenamed(in: app, nameButton: nameButton, field: field, from: "Газ горить", to: "Газ вимкнено", after: "вибору кольору")
    }

    // MARK: - Допоміжне

    /// Додає перемикач `old`, відкриває його, натискає назву, стирає її й друкує `new` (без «Готово»).
    @MainActor
    private func startRenaming(
        in app: XCUIApplication, from old: String, to new: String,
        file: StaticString = #filePath, line: UInt = #line
    ) -> (nameButton: XCUIElement, field: XCUIElement) {
        app.addSwitch(named: old, file: file, line: line)
        app.openSwitch(named: old, file: file, line: line)

        let nameButton = app.buttons[AccessibilityID.switchNameButton]
        nameButton.tap()
        let field = app.switchNameEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на назву не відкрило поле редагування", file: file, line: line)
        field.clearText()
        field.typeText(new)
        XCTAssertTrue(
            waitForValue(new, of: field),
            "У полі «\(field.value as? String ?? "")» замість «\(new)»", file: file, line: line
        )
        return (nameButton, field)
    }

    /// Поле закрилося, назва `new` показана на екрані перемикача і в списку, `old` — ніде.
    @MainActor
    private func assertRenamed(
        in app: XCUIApplication, nameButton: XCUIElement, field: XCUIElement,
        from old: String, to new: String, after step: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "Поле редагування не закрилося після \(step)", file: file, line: line)
        XCTAssertTrue(nameButton.waitForExistence(timeout: uiTimeout), "Немає назви на екрані перемикача", file: file, line: line)
        XCTAssertEqual(nameButton.label, new, "На екрані перемикача не нова назва", file: file, line: line)

        app.goBackToList(file: file, line: line)
        XCTAssertTrue(app.row(named: new).waitForExistence(timeout: uiTimeout), "У списку немає нової назви", file: file, line: line)
        XCTAssertFalse(app.row(named: old).exists, "У списку лишилася стара назва", file: file, line: line)
    }
}

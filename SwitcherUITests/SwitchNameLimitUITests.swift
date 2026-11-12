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

        let field = app.addSwitchNameField
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

        let field = app.switchNameEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля редагування назви")
        field.clearText()
        field.typeText(typed35)

        XCTAssertEqual(field.value as? String, String(typed35.prefix(30)))
        let counter = app.staticTexts[AccessibilityID.switchNameEditCounter]
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout))
        XCTAssertEqual(counter.label, "Символів: 30 з 30")
    }

    // MARK: - Повне поле, швидке введення серіями
    //
    // Поле доводять рівно до 30 символів і чекають, поки значення встоїться. Далі користувачка
    // продовжує швидко друкувати: кілька серій по 5 символів, кожна — одним `typeText`
    // (натискання без пауз між собою). Після кожної серії поле має встоятися на тих самих
    // 30 символах, а лічильник — показувати 30 з 30.
    //
    // Одиничні натискання з паузою (поле встоялося → ще один символ) баг не відтворюють:
    // 20 із 20 запусків зелені. Ламає саме кілька натискань поспіль, тому серій кілька —
    // кожна окремо ламає поле не щоразу.

    /// Серія символів, яку вводять у повне поле одним викликом.
    private let burst = "РСТУФ"
    /// Скільки серій поспіль.
    private let burstCount = 10

    /// Екран додавання: поле рівно повне (30) → 10 серій по 5 швидких натискань → після кожної серії 30 з 30.
    @MainActor
    func testAddFieldFullIgnoresRapidTyping() throws {
        let app = XCUIApplication.launchedForTesting()
        let (field, counter) = openFullAddField(in: app)

        for round in 1...burstCount {
            field.typeText(burst)
            assertFieldIsFull(field, counter: counter, after: "серія \(round) «\(burst)»")
        }
    }

    /// Екран перемикача: поле назви рівно повне (30) → 10 серій по 5 швидких натискань → після кожної серії 30 з 30.
    @MainActor
    func testRenameFieldFullIgnoresRapidTyping() throws {
        let app = XCUIApplication.launchedForTesting()
        let (field, counter) = openFullRenameField(in: app)

        for round in 1...burstCount {
            field.typeText(burst)
            assertFieldIsFull(field, counter: counter, after: "серія \(round) «\(burst)»")
        }
    }

    // MARK: - Допоміжне

    /// Відкриває екран додавання, вводить рівно 30 символів і чекає, поки поле й лічильник їх покажуть.
    @MainActor
    private func openFullAddField(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) -> (field: XCUIElement, counter: XCUIElement) {
        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку", file: file, line: line)
        app.addSwitchButton.tap()

        let field = app.addSwitchNameField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        field.tap()
        let counter = app.staticTexts[AccessibilityID.addSwitchNameCounter]
        fill(field, counter: counter, file: file, line: line)
        return (field, counter)
    }

    /// Відкриває поле редагування назви, стирає її, вводить рівно 30 символів і чекає, поки поле й лічильник їх покажуть.
    @MainActor
    private func openFullRenameField(
        in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line
    ) -> (field: XCUIElement, counter: XCUIElement) {
        app.addSwitch(named: "Ліки", file: file, line: line)
        app.openSwitch(named: "Ліки", file: file, line: line)
        app.buttons[AccessibilityID.switchNameButton].tap()

        let field = app.switchNameEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля редагування назви", file: file, line: line)
        field.clearText()
        let counter = app.staticTexts[AccessibilityID.switchNameEditCounter]
        fill(field, counter: counter, file: file, line: line)
        return (field, counter)
    }

    /// Вводить рівно 30 символів і чекає, поки значення поля й лічильник встояться.
    @MainActor
    private func fill(_ field: XCUIElement, counter: XCUIElement, file: StaticString, line: UInt) {
        let full = String(typed35.prefix(30))
        field.typeText(full)
        XCTAssertTrue(
            waitForValue(full, of: field),
            "Поле не дійшло до 30 символів: «\(field.value as? String ?? "")»", file: file, line: line
        )
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout), "Немає лічильника під полем", file: file, line: line)
        XCTAssertTrue(
            waitForLabel("Символів: 30 з 30", of: counter),
            "Лічильник «\(counter.label)» замість «Символів: 30 з 30»", file: file, line: line
        )
    }

    /// Після введення в повне поле значення поля встоюється на тих самих перших 30 символах,
    /// лічильник — «Символів: 30 з 30».
    @MainActor
    private func assertFieldIsFull(
        _ field: XCUIElement, counter: XCUIElement, after step: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        let full = String(typed35.prefix(30))
        let settled = waitForValue(full, of: field)
        let value = field.value as? String ?? ""
        XCTAssertTrue(
            settled,
            "Після: \(step) — у полі \(value.count) символів «\(value)», лічильник «\(counter.label)»",
            file: file, line: line
        )
        XCTAssertTrue(
            waitForLabel("Символів: 30 з 30", of: counter),
            "Після: \(step) — лічильник «\(counter.label)»", file: file, line: line
        )
    }
}

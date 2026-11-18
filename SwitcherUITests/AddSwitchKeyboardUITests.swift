import XCTest

/// Клавіатура на екрані «Новий перемикач»: вона не відкривається сама, а «Готово» на ній лише
/// ховає клавіатуру — перемикач створює тільки кнопка «Додати».
final class AddSwitchKeyboardUITests: XCTestCase {
    /// Скільки чекати, щоб переконатися, що чогось НЕ сталося (клавіатура не з'явилася,
    /// екран не закрився): більше за анімацію появи аркуша й клавіатури.
    private let quietPeriod: TimeInterval = 3

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Відкрили екран додавання → поле «Назва» є, але без фокуса й без клавіатури.
    /// Натиснули на поле → з'явилася клавіатура (це заодно перевіряє, що симулятор узагалі
    /// показує екранну клавіатуру, тобто перша перевірка не порожня).
    @MainActor
    func testAddScreenOpensWithoutKeyboard() throws {
        let app = XCUIApplication.launchedForTesting()
        let field = openAddScreen(in: app)

        XCTAssertTrue(
            stays(app.keyboards.firstMatch, withoutBecoming: "exists == true", for: quietPeriod),
            "Клавіатура відкрилася сама одразу після відкриття екрана додавання"
        )
        XCTAssertFalse(hasKeyboardFocus(field), "Поле «Назва» у фокусі одразу після відкриття екрана")

        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Натискання на поле не відкрило клавіатуру")
        XCTAssertTrue(waitForKeyboardFocus(true, of: field), "Після натискання поле «Назва» не у фокусі")
    }

    /// Ввели назву, натиснули «Готово» на клавіатурі → клавіатура сховалася, поле без фокуса,
    /// екран додавання відкритий, назва в полі, «Додати» доступна. Повторно: торкнулися поля,
    /// знову «Готово» → те саме. «Скасувати» → у списку перемикача з цією назвою немає.
    @MainActor
    func testDoneOnKeyboardHidesKeyboardWithoutCreatingSwitch() throws {
        let app = XCUIApplication.launchedForTesting()
        let name = "Полила квіти"
        let field = openAddScreen(in: app)
        let save = app.buttons[AccessibilityID.addSwitchSaveButton]

        typeName(name, into: field, in: app)
        for attempt in ["першого", "повторного"] {
            if attempt == "повторного" {
                field.tap()
                XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Повторне натискання на поле не відкрило клавіатуру")
            }
            pressDone(on: field, in: app, step: "\(attempt) «Готово»")

            XCTAssertTrue(waitForValue(name, of: field), "Після \(attempt) «Готово» у полі «\(field.value as? String ?? "")» замість «\(name)»")
            XCTAssertFalse(hasKeyboardFocus(field), "Після \(attempt) «Готово» поле «Назва» лишилося у фокусі")
            XCTAssertTrue(save.exists && save.isEnabled, "Після \(attempt) «Готово» кнопка «Додати» недоступна")
        }

        let cancel = app.buttons[AccessibilityID.addSwitchCancelButton]
        XCTAssertTrue(cancel.waitForExistence(timeout: uiTimeout), "Немає кнопки «Скасувати» на екрані додавання")
        cancel.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "«Скасувати» не закрило екран додавання")
        XCTAssertTrue(waitUntilHittable(app.addSwitchButton), "Список не показано після «Скасувати»")
        XCTAssertFalse(app.row(named: name).exists, "Перемикач «\(name)» створився, хоча «Додати» не натискали")
    }

    /// Ввели назву, «Готово» → екран лишився → обрали колір «Корал» і значок 🔥 →
    /// «Додати» → рядок у списку, а на екрані перемикача обрано саме ці колір і значок.
    @MainActor
    func testSwitchIsCreatedByAddButtonAfterChoosingColorAndIcon() throws {
        let app = XCUIApplication.launchedForTesting()
        let name = "Газ горить"
        let field = openAddScreen(in: app)

        typeName(name, into: field, in: app)
        pressDone(on: field, in: app, step: "«Готово»")

        // За замовчуванням — бурштиновий колір і ✔️ (див. IconPickerUITests); «Корал» і 🔥 — інші.
        let coral = app.buttons[AccessibilityID.toneOption("coral")]
        let flame = app.buttons[AccessibilityID.iconOption("🔥")]
        choose(coral, what: "колір «Корал»")
        choose(flame, what: "значок 🔥")

        let save = app.buttons[AccessibilityID.addSwitchSaveButton]
        XCTAssertTrue(save.waitForExistence(timeout: uiTimeout), "Немає кнопки «Додати»")
        save.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "«Додати» не закрило екран додавання")
        XCTAssertTrue(app.row(named: name).waitForExistence(timeout: uiTimeout), "Рядок «\(name)» не з'явився в списку після «Додати»")

        app.openSwitch(named: name)
        XCTAssertTrue(waitForSelected(coral), "На екрані перемикача не обрано колір «Корал»")
        XCTAssertTrue(waitForSelected(flame), "На екрані перемикача не обрано значок 🔥")
    }

    // MARK: - Допоміжне

    /// Натискає «+» у списку і чекає на поле «Назва» та кнопку «Додати» (аркуш догорнувся).
    @MainActor
    private func openAddScreen(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку", file: file, line: line)
        app.addSwitchButton.tapAfterSystemBanner()
        let field = app.addSwitchNameField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        XCTAssertTrue(
            waitUntilHittable(app.buttons[AccessibilityID.addSwitchSaveButton]),
            "Екран додавання не показано повністю", file: file, line: line
        )
        return field
    }

    /// Торкається поля, чекає на клавіатуру й друкує `name` (без «Готово»).
    @MainActor
    private func typeName(_ name: String, into field: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Натискання на поле не відкрило клавіатуру", file: file, line: line)
        field.typeText(name)
        XCTAssertTrue(waitForValue(name, of: field), "У полі «\(field.value as? String ?? "")» замість «\(name)»", file: file, line: line)
    }

    /// Натискає «Готово» на клавіатурі (перенос рядка — return key поля) і перевіряє,
    /// що клавіатура сховалася, а екран додавання лишився відкритим.
    @MainActor
    private func pressDone(on field: XCUIElement, in app: XCUIApplication, step: String, file: StaticString = #filePath, line: UInt = #line) {
        field.typeText("\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: uiTimeout), "Після \(step) клавіатура не сховалася", file: file, line: line)
        XCTAssertTrue(
            stays(field, withoutBecoming: "exists == false", for: quietPeriod),
            "Після \(step) екран додавання закрився (перемикач створено без «Додати»)", file: file, line: line
        )
    }

    /// Натискає кнопку вибору й чекає, поки вона стане обраною.
    @MainActor
    private func choose(_ option: XCUIElement, what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(option.waitForExistence(timeout: uiTimeout), "Немає кнопки: \(what)", file: file, line: line)
        XCTAssertFalse(option.isSelected, "\(what) уже обрано — тест не перевірить вибір", file: file, line: line)
        option.tap()
        XCTAssertTrue(waitForSelected(option), "Натискання не обрало \(what)", file: file, line: line)
    }

    /// Чи має елемент фокус клавіатури (атрибут XCUITest `hasKeyboardFocus`).
    @MainActor
    private func hasKeyboardFocus(_ element: XCUIElement) -> Bool {
        (element.value(forKey: "hasKeyboardFocus") as? Bool) ?? false
    }

    @MainActor
    private func waitForKeyboardFocus(_ focused: Bool, of element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hasKeyboardFocus == %@", NSNumber(value: focused)), object: element
        )
        return XCTWaiter().wait(for: [expectation], timeout: uiTimeout) == .completed
    }
}

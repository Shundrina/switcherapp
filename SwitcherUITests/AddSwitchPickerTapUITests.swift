import XCTest

/// Екран «Новий перемикач»: кольори й основні значки вибираються з першого натискання.
///
/// Баг: картка-зразок «Вигляд у списку» стоїть у розмітці після сіток вибору (поверх них), а її
/// кольорове тло в увімкненому стані — коло, набагато більше за саму картку. Обрізане лише малювання,
/// а не зона натискання, тож коло перехоплювало дотики до сіток, і вибір спрацьовував через раз.
/// У тестовому режимі (`-UITesting`) картка-зразок стоїть увімкненою — найгірший для натискань стан, —
/// тож кожне натискання нижче мусить влучити в кнопку, а не в картку.
final class AddSwitchPickerTapUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Відкрили екран додавання → по одному разу натиснули кожен колір, починаючи з не обраних
    /// (за замовчуванням обрано «Бурштин», тож він останній) → кожне натискання одразу обирає колір.
    @MainActor
    func testEachColorIsSelectedByFirstTap() throws {
        let app = XCUIApplication.launchedForTesting()
        openAddScreen(in: app)

        let amber = app.buttons[AccessibilityID.toneOption("amber")]
        XCTAssertTrue(amber.waitForExistence(timeout: uiTimeout), "Немає кольору «Бурштин»")
        XCTAssertTrue(amber.isSelected, "За замовчуванням не обрано колір «Бурштин»")

        for (rawValue, title) in [("coral", "Корал"), ("mint", "М'ята"), ("sky", "Небо"), ("lilac", "Бузок"), ("pink", "Рожевий"), ("amber", "Бурштин")] {
            tapOnce(app.buttons[AccessibilityID.toneOption(rawValue)], what: "колір «\(title)»")
        }
    }

    /// Відкрили екран додавання → по одному разу натиснули кожен з семи основних значків, починаючи
    /// з не обраних (за замовчуванням обрано ✔️, тож він останній) → кожне натискання одразу обирає значок.
    @MainActor
    func testEachFeaturedIconIsSelectedByFirstTap() throws {
        let app = XCUIApplication.launchedForTesting()
        openAddScreen(in: app)

        // ✔️ — U+2714 U+FE0F, як його видає клавіатура.
        let check = "\u{2714}\u{FE0F}"
        let checkCell = app.buttons[AccessibilityID.iconOption(check)]
        XCTAssertTrue(checkCell.waitForExistence(timeout: uiTimeout), "Немає комірки ✔️ у сітці значків")
        XCTAssertTrue(checkCell.isSelected, "За замовчуванням не обрано значок ✔️")

        for emoji in ["🔥", "🔒", "💊", "🔌", "🪴", "💧", check] {
            tapOnce(app.buttons[AccessibilityID.iconOption(emoji)], what: "значок \(emoji)")
        }
    }

    // MARK: - Допоміжне

    /// Натискає «+» у списку і чекає, поки екран додавання покажеться повністю.
    @MainActor
    private func openAddScreen(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку", file: file, line: line)
        app.addSwitchButton.tapAfterSystemBanner(file: file, line: line)
        XCTAssertTrue(app.addSwitchNameField.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        XCTAssertTrue(
            waitUntilHittable(app.buttons[AccessibilityID.addSwitchSaveButton]),
            "Екран додавання не показано повністю", file: file, line: line
        )
    }

    /// Натискає не обрану кнопку вибору рівно один раз і перевіряє, що вона стала обраною.
    /// Повторних натискань немає: пропущене натискання — це і є баг.
    @MainActor
    private func tapOnce(_ option: XCUIElement, what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(option.waitForExistence(timeout: uiTimeout), "Немає кнопки: \(what)", file: file, line: line)
        XCTAssertFalse(option.isSelected, "\(what) уже обрано — тест не перевірить вибір", file: file, line: line)
        option.tap()
        XCTAssertTrue(waitForSelected(option), "Натискання не обрало \(what) з першого разу", file: file, line: line)
    }
}

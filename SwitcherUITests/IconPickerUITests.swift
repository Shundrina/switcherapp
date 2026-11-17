import XCTest

/// Значки-емодзі: сітка з семи основних і восьмої комірки «…», яка відкриває «Усі значки».
/// Значок не з основних після вибору показується у восьмій комірці замість «…».
final class IconPickerUITests: XCTestCase {
    /// ✔️ — U+2714 U+FE0F, як його видає клавіатура.
    private let check = "\u{2714}\u{FE0F}"
    /// Не з основних, у розділі «Дім» — видно на екрані «Усі значки» без прокрутки.
    private let basket = "🧺"
    /// Основний, і він же є в розділі «Дім».
    private let lock = "🔒"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Відкрили екран додавання → одразу обрано бурштиновий колір і ✔️, а «…» не обрано.
    @MainActor
    func testAddScreenDefaultsToAmberAndCheck() throws {
        let app = XCUIApplication.launchedForTesting()
        openAddScreen(in: app)

        let amber = app.buttons[AccessibilityID.toneOption("amber")]
        XCTAssertTrue(amber.waitForExistence(timeout: uiTimeout), "Немає кольору «Бурштин»")
        XCTAssertTrue(amber.isSelected, "За замовчуванням не обрано колір «Бурштин»")

        let checkCell = app.buttons[AccessibilityID.iconOption(check)]
        XCTAssertTrue(checkCell.waitForExistence(timeout: uiTimeout), "Немає комірки ✔️ у сітці значків")
        XCTAssertTrue(checkCell.isSelected, "За замовчуванням не обрано значок ✔️")

        let more = app.buttons[AccessibilityID.iconOptionMore]
        XCTAssertTrue(more.waitForExistence(timeout: uiTimeout), "Немає восьмої комірки «…»")
        XCTAssertFalse(more.isSelected, "«…» обрано, хоча вибрано ✔️")
        XCTAssertEqual(more.label, "Усі значки", "Мітка VoiceOver комірки «…»")
    }

    /// Екран додавання: «…» → «Усі значки» → 🧺 → екран закрився, 🧺 у восьмій комірці замість «…»
    /// й обраний → «Додати» → на екрані перемикача обрано 🧺.
    @MainActor
    func testAddScreenIconFromAllIconsReplacesMoreAndIsSaved() throws {
        let app = XCUIApplication.launchedForTesting()
        let name = "Прання"
        let field = openAddScreen(in: app)

        pick(basket, from: app.buttons[AccessibilityID.iconOptionMore], what: "«…»", in: app)
        expectEighthCell(showing: basket, in: app)
        XCTAssertFalse(app.buttons[AccessibilityID.iconOption(check)].isSelected, "✔️ лишився обраним після вибору 🧺")

        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Натискання на поле не відкрило клавіатуру")
        field.typeText(name)
        let save = app.buttons[AccessibilityID.addSwitchSaveButton]
        XCTAssertTrue(save.waitForExistence(timeout: uiTimeout), "Немає кнопки «Додати»")
        save.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "«Додати» не закрило екран додавання")

        app.openSwitch(named: name)
        expectEighthCell(showing: basket, in: app, where: "на екрані перемикача")
    }

    /// Екран додавання: обрали 🧺 з «Усіх значків» → натиснули восьму комірку з 🧺 → знову «Усі значки»,
    /// у них виділено 🧺 → обрали основний 🔒 → у восьмій комірці знову «…», обрано 🔒.
    @MainActor
    func testAddScreenFeaturedIconFromAllIconsBringsBackMore() throws {
        let app = XCUIApplication.launchedForTesting()
        openAddScreen(in: app)

        pick(basket, from: app.buttons[AccessibilityID.iconOptionMore], what: "«…»", in: app)
        expectEighthCell(showing: basket, in: app)

        pick(lock, from: app.buttons[AccessibilityID.iconOption(basket)], what: "восьма комірка з 🧺", in: app, currentSelection: basket)
        expectMoreCell(withFeaturedSelected: lock, in: app)
    }

    /// Екран перемикача: «…» → 🧺 → 🧺 у восьмій комірці й обраний; після повернення до списку
    /// й повторного відкриття — так само (значок збережено).
    @MainActor
    func testSwitchScreenIconFromAllIconsReplacesMore() throws {
        let app = XCUIApplication.launchedForTesting()
        let name = "Прання"
        app.addSwitch(named: name)
        app.openSwitch(named: name)

        XCTAssertTrue(waitForSelected(app.buttons[AccessibilityID.iconOption(check)]), "На екрані нового перемикача не обрано ✔️")
        pick(basket, from: app.buttons[AccessibilityID.iconOptionMore], what: "«…»", in: app, currentSelection: nil)
        expectEighthCell(showing: basket, in: app, where: "на екрані перемикача")

        app.goBackToList()
        app.openSwitch(named: name)
        expectEighthCell(showing: basket, in: app, where: "після повторного відкриття екрана перемикача")
    }

    /// Екран перемикача: обрали 🧺 з «Усіх значків» → восьма комірка з 🧺 → «Усі значки» з виділеним 🧺 →
    /// основний 🔒 → у восьмій комірці «…», обрано 🔒; після повторного відкриття — так само.
    @MainActor
    func testSwitchScreenFeaturedIconFromAllIconsBringsBackMore() throws {
        let app = XCUIApplication.launchedForTesting()
        let name = "Двері зачинені"
        app.addSwitch(named: name)
        app.openSwitch(named: name)

        pick(basket, from: app.buttons[AccessibilityID.iconOptionMore], what: "«…»", in: app, currentSelection: nil)
        expectEighthCell(showing: basket, in: app, where: "на екрані перемикача")

        pick(lock, from: app.buttons[AccessibilityID.iconOption(basket)], what: "восьма комірка з 🧺", in: app, currentSelection: basket)
        expectMoreCell(withFeaturedSelected: lock, in: app, where: "на екрані перемикача")

        app.goBackToList()
        app.openSwitch(named: name)
        expectMoreCell(withFeaturedSelected: lock, in: app, where: "після повторного відкриття екрана перемикача")
    }

    // MARK: - Допоміжне

    /// Натискає «+» у списку і чекає, поки екран додавання покажеться повністю.
    @MainActor
    @discardableResult
    private func openAddScreen(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку", file: file, line: line)
        app.addSwitchButton.tap()
        let field = app.addSwitchNameField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        XCTAssertTrue(
            waitUntilHittable(app.buttons[AccessibilityID.addSwitchSaveButton]),
            "Екран додавання не показано повністю", file: file, line: line
        )
        return field
    }

    /// Натискає `opener` (восьму комірку), перевіряє, що відкрилися «Усі значки» й у них виділено
    /// `currentSelection` (якщо задано), обирає `emoji` і перевіряє, що екран закрився.
    @MainActor
    private func pick(
        _ emoji: String, from opener: XCUIElement, what: String, in app: XCUIApplication,
        currentSelection: String? = nil, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(opener.waitForExistence(timeout: uiTimeout), "Немає комірки: \(what)", file: file, line: line)
        opener.tap()

        let option = app.buttons[AccessibilityID.allIconsOption(emoji)]
        XCTAssertTrue(option.waitForExistence(timeout: uiTimeout), "\(what) не відкрило «Усі значки» (немає \(emoji))", file: file, line: line)
        if let currentSelection {
            XCTAssertTrue(
                waitForSelected(app.buttons[AccessibilityID.allIconsOption(currentSelection)]),
                "В «Усіх значках» не виділено поточний значок \(currentSelection)", file: file, line: line
            )
        }
        XCTAssertFalse(option.isSelected, "\(emoji) уже виділено в «Усіх значках» — тест не перевірить вибір", file: file, line: line)
        option.tap()
        XCTAssertTrue(option.waitForNonExistence(timeout: uiTimeout), "Вибір \(emoji) не закрив «Усі значки»", file: file, line: line)
    }

    /// Восьма комірка показує `emoji` (не з основних) і обрана; «…» немає.
    @MainActor
    private func expectEighthCell(showing emoji: String, in app: XCUIApplication, where place: String = "", file: StaticString = #filePath, line: UInt = #line) {
        let cell = app.buttons[AccessibilityID.iconOption(emoji)]
        XCTAssertTrue(cell.waitForExistence(timeout: uiTimeout), "У сітці немає комірки з \(emoji) \(place)", file: file, line: line)
        XCTAssertTrue(waitForSelected(cell), "Комірку з \(emoji) не обрано \(place)", file: file, line: line)
        XCTAssertFalse(app.buttons[AccessibilityID.iconOptionMore].exists, "Замість \(emoji) у восьмій комірці лишилося «…» \(place)", file: file, line: line)
    }

    /// Обрано основний `emoji`, у восьмій комірці — «…» (не обрана), значка 🧺 у сітці немає.
    @MainActor
    private func expectMoreCell(withFeaturedSelected emoji: String, in app: XCUIApplication, where place: String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(waitForSelected(app.buttons[AccessibilityID.iconOption(emoji)]), "Не обрано \(emoji) \(place)", file: file, line: line)
        let more = app.buttons[AccessibilityID.iconOptionMore]
        XCTAssertTrue(more.waitForExistence(timeout: uiTimeout), "У восьмій комірці не повернулося «…» \(place)", file: file, line: line)
        XCTAssertFalse(more.isSelected, "«…» обрано, хоча вибрано основний \(emoji) \(place)", file: file, line: line)
        XCTAssertFalse(app.buttons[AccessibilityID.iconOption(basket)].exists, "\(basket) лишився в сітці \(place)", file: file, line: line)
    }
}

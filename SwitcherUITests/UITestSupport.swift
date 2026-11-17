import XCTest

/// Аргументи запуску тестового режиму застосунку.
enum LaunchArgument {
    /// Сховище лише в пам'яті (порожнє на кожному запуску), онбординг пропущено без запису в UserDefaults.
    static let uiTesting = "-UITesting"
    /// Разом з `uiTesting`: онбординг показано незалежно від збереженого прапорця.
    static let showOnboarding = "-UITestingShowOnboarding"
}

/// Ідентифікатори доступності, на які спираються екранні тести.
enum AccessibilityID {
    // Список (ContentView)
    static let addSwitchButton = "addSwitchButton"
    static let switchRowOpenButton = "switchRowOpenButton"
    static let switchRowToggle = "switchRowToggle"
    // Додавання (AddSwitchView)
    static let addSwitchNameField = "addSwitchNameField"
    static let addSwitchNameCounter = "addSwitchNameCounter"
    static let addSwitchSaveButton = "addSwitchSaveButton"
    static let addSwitchCancelButton = "addSwitchCancelButton"
    // Екран перемикача (SwitchHistoryView)
    static let switchNameButton = "switchNameButton"
    static let switchNameEditField = "switchNameEditField"
    static let switchNameEditCounter = "switchNameEditCounter"
    static let historyEmptyText = "historyEmptyText"
    static let historyEvent = "historyEvent"
    // Вибір кольору (TonePicker): кнопка кольору `tone` — `"toneOption_" + SwitchTone.rawValue`.
    static func toneOption(_ tone: String) -> String { "toneOption_\(tone)" }
    // Вибір значка (IconPicker, сітка 4×2 на екранах додавання й перемикача): комірка, у якій
    // показано емодзі `emoji`, — `"iconOption_" + емодзі` (SwitchIcon.rawValue, з U+FE0F, де він є).
    // Це й сім основних, і восьма комірка, коли в ній показано вибраний значок не з основних.
    static func iconOption(_ emoji: String) -> String { "iconOption_\(emoji)" }
    // Восьма комірка, поки в ній «…» (відкриває «Усі значки»).
    static let iconOptionMore = "iconOptionMore"
    // Екран «Усі значки»: кнопка емодзі `emoji` — `"allIconsOption_" + емодзі`.
    static func allIconsOption(_ emoji: String) -> String { "allIconsOption_\(emoji)" }
}

/// Скільки чекати на появу елемента: з урахуванням анімацій і повільного симулятора.
let uiTimeout: TimeInterval = 10

extension XCUIApplication {
    /// Запускає застосунок у тестовому режимі: порожнє сховище в пам'яті, онбординг пропущено
    /// (або показано, якщо `showOnboarding`).
    @MainActor
    static func launchedForTesting(showOnboarding: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting]
        if showOnboarding {
            app.launchArguments.append(LaunchArgument.showOnboarding)
        }
        app.launch()
        return app
    }

    /// Кнопка «+» у заголовку списку.
    @MainActor
    var addSwitchButton: XCUIElement {
        buttons[AccessibilityID.addSwitchButton]
    }

    /// Поле «Назва» на екрані додавання — однорядковий `UITextField`.
    @MainActor
    var addSwitchNameField: XCUIElement {
        textFields[AccessibilityID.addSwitchNameField]
    }

    /// Поле редагування назви на екрані перемикача — багаторядковий `UITextView`.
    @MainActor
    var switchNameEditField: XCUIElement {
        textViews[AccessibilityID.switchNameEditField]
    }

    /// Прокрутка екрана перемикача. Шукається в головному вікні: `app.scrollViews.firstMatch`
    /// при відкритій клавіатурі знаходить смугу підказок над нею (теж `ScrollView`, у вікні клавіатури).
    @MainActor
    var switchScreenScrollView: XCUIElement {
        windows.element(boundBy: 0).scrollViews.firstMatch
    }

    /// Рядок списку, у якому є елемент з назвою `name` (назву задає сам тест, тож вона стабільна).
    @MainActor
    func row(named name: String) -> XCUIElement {
        cells.containing(NSPredicate(format: "label == %@", name)).firstMatch
    }

    /// Додає перемикач через екран додавання і чекає, поки його рядок з'явиться в списку.
    @MainActor
    @discardableResult
    func addSwitch(named name: String, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        XCTAssertTrue(addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку", file: file, line: line)
        addSwitchButton.tap()

        let field = addSwitchNameField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        field.tap()
        field.typeText(name)

        let save = buttons[AccessibilityID.addSwitchSaveButton]
        XCTAssertTrue(save.waitForExistence(timeout: uiTimeout), "Немає кнопки «Додати»", file: file, line: line)
        save.tap()

        let row = row(named: name)
        XCTAssertTrue(row.waitForExistence(timeout: uiTimeout), "Рядок «\(name)» не з'явився в списку", file: file, line: line)
        return row
    }

    /// Відкриває екран перемикача з рядка списку.
    @MainActor
    func openSwitch(named name: String, file: StaticString = #filePath, line: UInt = #line) {
        let open = row(named: name).buttons[AccessibilityID.switchRowOpenButton]
        XCTAssertTrue(open.waitForExistence(timeout: uiTimeout), "Немає кнопки відкриття в рядку «\(name)»", file: file, line: line)
        open.tap()
        XCTAssertTrue(
            buttons[AccessibilityID.switchNameButton].waitForExistence(timeout: uiTimeout),
            "Екран перемикача не відкрився", file: file, line: line
        )
    }

    /// Повертається з екрана перемикача до списку.
    @MainActor
    func goBackToList(file: StaticString = #filePath, line: UInt = #line) {
        let back = navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: uiTimeout), "Немає кнопки «Назад»", file: file, line: line)
        back.tap()
        XCTAssertTrue(addSwitchButton.waitForExistence(timeout: uiTimeout), "Список не показано", file: file, line: line)
    }
}

extension XCUIElement {
    /// Свайп ліворуч, який відкриває дії рядка й не доходить до «повного свайпу»: `swipeLeft()` буває
    /// надто довгим, і тоді список одразу виконує першу дію, не показавши кнопку.
    @MainActor
    func revealTrailingSwipeActions() {
        let start = coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let end = coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.1)
    }

    /// Стирає текст у полі, яке вже має фокус клавіатури (курсор у кінці).
    @MainActor
    func clearText() {
        let current = (value as? String) ?? ""
        guard !current.isEmpty else { return }
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
    }
}

extension XCTestCase {
    /// Чекає, поки елемент стане доступним для натискання (наприклад, сторінка онбордингу догорнулася).
    @MainActor
    func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = uiTimeout) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Чекає, поки значення елемента (`value`) стане `expected`.
    @MainActor
    func waitForValue(_ expected: String, of element: XCUIElement, timeout: TimeInterval = uiTimeout) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Перевіряє, що умова `format` для елемента НЕ стала істинною за `duration` секунд
    /// (наприклад, клавіатура не з'явилася, екран не закрився). Повертає `true`, якщо так і було.
    @MainActor
    func stays(_ element: XCUIElement, withoutBecoming format: String, for duration: TimeInterval) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: format), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: duration) == .timedOut
    }

    /// Чекає, поки елемент стане обраним (риса доступності `isSelected`).
    @MainActor
    func waitForSelected(_ element: XCUIElement, timeout: TimeInterval = uiTimeout) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Чекає, поки мітка елемента (`label`) стане `expected`.
    @MainActor
    func waitForLabel(_ expected: String, of element: XCUIElement, timeout: TimeInterval = uiTimeout) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

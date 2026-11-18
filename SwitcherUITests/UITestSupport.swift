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
    static let addSwitchNoteField = "addSwitchNoteField"
    static let addSwitchNoteCounter = "addSwitchNoteCounter"
    /// Видима рамка поля «Примітка» (заокруглений прямокутник навколо поля) — один елемент на всю рамку.
    static let addSwitchNoteFrame = "addSwitchNoteFrame"
    // Екран перемикача (SwitchHistoryView)
    static let switchNameButton = "switchNameButton"
    static let switchNameEditField = "switchNameEditField"
    static let switchNameEditCounter = "switchNameEditCounter"
    /// Примітка в картці: кнопка з текстом примітки або, якщо її немає, «Додати примітку».
    static let switchNoteButton = "switchNoteButton"
    static let switchNoteEditField = "switchNoteEditField"
    static let switchNoteEditCounter = "switchNoteEditCounter"
    /// Кнопка «Готово» на панелі над клавіатурою, коли редагується примітка (обидва екрани).
    static let noteKeyboardDoneButton = "noteKeyboardDoneButton"
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

/// Похибка плаваючої коми в розмірах елементів: на екранах @3x з дробовим зсувом (наприклад, y = 252.67)
/// висота 44 pt приходить як 43.99999999999997. Набагато менша за піксель (1/3 pt), тож вимог не послаблює.
let layoutTolerance: CGFloat = 0.001

extension XCUIApplication {
    /// Запускає застосунок у тестовому режимі: порожнє сховище в пам'яті, онбординг пропущено
    /// (або показано, якщо `showOnboarding`). `environment` — додаткові змінні середовища процесу
    /// застосунку (наприклад, `"TZ"` — часовий пояс).
    @MainActor
    static func launchedForTesting(showOnboarding: Bool = false, environment: [String: String] = [:]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting]
        if showOnboarding {
            app.launchArguments.append(LaunchArgument.showOnboarding)
        }
        app.launchEnvironment.merge(environment) { _, new in new }
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

    /// Поле «Примітка» на екрані додавання — багаторядкове (`UITextView`).
    @MainActor
    var addSwitchNoteField: XCUIElement {
        textViews[AccessibilityID.addSwitchNoteField]
    }

    /// Поле редагування примітки на екрані перемикача — багаторядкове (`UITextView`).
    @MainActor
    var switchNoteEditField: XCUIElement {
        textViews[AccessibilityID.switchNoteEditField]
    }

    /// Примітка в картці на екрані перемикача (або «Додати примітку»).
    @MainActor
    var switchNoteButton: XCUIElement {
        buttons[AccessibilityID.switchNoteButton]
    }

    /// Кнопка «Готово» над клавіатурою в полі примітки.
    @MainActor
    var noteKeyboardDoneButton: XCUIElement {
        buttons[AccessibilityID.noteKeyboardDoneButton]
    }

    /// Прокрутка екрана перемикача. Шукається в головному вікні: `app.scrollViews.firstMatch`
    /// при відкритій клавіатурі знаходить смугу підказок над нею (теж `ScrollView`, у вікні клавіатури).
    @MainActor
    var switchScreenScrollView: XCUIElement {
        windows.element(boundBy: 0).scrollViews.firstMatch
    }

    /// Прокручує екран перемикача вгору так, як це зробила б людина з відкритою екранною клавіатурою:
    /// пальцем по видимій частині екрана над клавіатурою. `swipeUp()` по всьому `ScrollView` починає
    /// жест там, де його закриває клавіатура, і тоді жест дістається клавіатурі, а не прокрутці.
    /// Жест іде по правому полю екрана (поза картками й кнопками) — щоб це не сприйнялося як натискання.
    @MainActor
    func scrollSwitchScreenUpAboveKeyboard(file: StaticString = #filePath, line: UInt = #line) {
        let scrollView = switchScreenScrollView
        XCTAssertTrue(scrollView.waitForExistence(timeout: uiTimeout), "Немає прокрутки екрана перемикача — відкрито інший екран?", file: file, line: line)
        let scrollFrame = scrollView.frame
        let keyboard = keyboards.firstMatch
        // Верх клавіатури (без смуги підказок і панелі над нею, тож із запасом), або низ прокрутки, якщо клавіатури немає.
        let visibleBottom = keyboard.exists ? min(keyboard.frame.minY, scrollFrame.maxY) : scrollFrame.maxY
        let origin = coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: scrollFrame.maxX - 8, dy: visibleBottom * 0.6))
        let end = origin.withOffset(CGVector(dx: scrollFrame.maxX - 8, dy: visibleBottom * 0.15))
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .default, thenHoldForDuration: 0.05)
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
        addSwitchButton.tapAfterSystemBanner(file: file, line: line)

        let field = addSwitchNameField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        field.tap()
        field.typeText(name)

        let save = buttons[AccessibilityID.addSwitchSaveButton]
        XCTAssertTrue(save.waitForExistence(timeout: uiTimeout), "Немає кнопки «Додати»", file: file, line: line)
        save.tapAfterSystemBanner(file: file, line: line)

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
        back.tapAfterSystemBanner(file: file, line: line)
        XCTAssertTrue(addSwitchButton.waitForExistence(timeout: uiTimeout), "Список не показано", file: file, line: line)
    }
}

/// Скільки чекати, поки системний банер сповіщення сховається сам (на iPhone — близько 5 с).
let systemBannerTimeout: TimeInterval = 15

extension XCUIElement {
    /// Натискає, дочекавшись, поки зникне системний банер сповіщення. На справжньому iPhone банер
    /// (повідомлення з інших застосунків) з'являється згори й перекриває «+», «Назад», «Додати»:
    /// натискання дістається банеру, а не кнопці. У симуляторі банерів зазвичай немає — тоді просто натискає.
    @MainActor
    func tapAfterSystemBanner(file: StaticString = #filePath, line: UInt = #line) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let banner = springboard.descendants(matching: .any).matching(identifier: "NotificationShortLookView").firstMatch
        if banner.exists, !banner.waitForNonExistence(timeout: systemBannerTimeout) {
            XCTFail(
                "Системний банер сповіщення не зник за \(Int(systemBannerTimeout)) с і перекриває верх екрана — на iPhone увімкніть «Не турбувати»",
                file: file, line: line
            )
            return
        }
        tap()
    }

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

    /// Чекає, поки текстове поле стане порожнім. Порожній `UITextView` у симуляторі повертає
    /// `value` == `""`, а на справжньому iPhone — `nil`; обидва означають «порожньо».
    @MainActor
    func waitForEmptyValue(of element: XCUIElement, timeout: TimeInterval = uiTimeout) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == nil OR value == ''"), object: element)
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

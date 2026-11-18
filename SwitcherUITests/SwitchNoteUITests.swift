import XCTest

/// Необов'язкова примітка до перемикача (до 200 символів, багаторядкова): поле на екрані додавання,
/// показ і редагування на місці в картці екрана перемикача; у списку примітки не видно.
/// Return у полі примітки вставляє перенос рядка; редагування завершує «Готово» над клавіатурою.
final class SwitchNoteUITests: XCTestCase {
    /// Скільки чекати, щоб переконатися, що чогось НЕ сталося.
    private let quietPeriod: TimeInterval = 3
    /// Напис на місці примітки, коли її немає.
    private let addNoteLabel = "Додати примітку"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Екран додавання

    /// Екран додавання: ввести примітку з переносом рядка (Return вставляє перенос, у кінці — теж) →
    /// «Додати» недоступна без назви → «Готово» над клавіатурою ховає клавіатуру, екран лишається →
    /// ввести назву → «Додати» → у списку примітки не видно ні текстом, ні в мітках → на екрані
    /// перемикача примітка повністю, з переносом, без переносу в кінці.
    @MainActor
    func testNoteFromAddScreenIsShownOnSwitchScreenButNotInList() throws {
        let app = XCUIApplication.launchedForTesting()
        let name = "Вазони"
        let firstLine = "Поливати по суботах"
        let secondLine = "Перевірити землю"
        let typed = "\(firstLine)\n\(secondLine)\n"
        let saved = "\(firstLine)\n\(secondLine)"

        openAddScreen(in: app)
        let noteField = app.addSwitchNoteField
        XCTAssertTrue(noteField.waitForExistence(timeout: uiTimeout), "Немає поля «Примітка» на екрані додавання")
        noteField.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Натискання на поле примітки не відкрило клавіатуру")
        noteField.typeText(typed)
        XCTAssertTrue(
            waitForValue(typed, of: noteField),
            "Return має вставляти перенос рядка; у полі «\(noteField.value as? String ?? "")»"
        )
        XCTAssertTrue(app.keyboards.firstMatch.exists, "Return у полі примітки сховав клавіатуру")

        let save = app.buttons[AccessibilityID.addSwitchSaveButton]
        XCTAssertFalse(save.isEnabled, "«Додати» доступна без назви — примітка не має на це впливати")

        let done = app.noteKeyboardDoneButton
        XCTAssertTrue(done.waitForExistence(timeout: uiTimeout), "Немає кнопки «Готово» над клавіатурою в полі примітки")
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: uiTimeout), "«Готово» не сховало клавіатуру")
        XCTAssertTrue(
            stays(noteField, withoutBecoming: "exists == false", for: quietPeriod),
            "Після «Готово» екран додавання закрився"
        )
        XCTAssertEqual(noteField.value as? String, typed, "«Готово» змінило текст примітки")

        let nameField = app.addSwitchNameField
        nameField.tap()
        nameField.typeText(name)
        XCTAssertTrue(waitForValue(name, of: nameField), "У полі назви «\(nameField.value as? String ?? "")»")
        XCTAssertTrue(save.isEnabled, "«Додати» недоступна, хоча назву введено")
        save.tap()

        XCTAssertTrue(app.row(named: name).waitForExistence(timeout: uiTimeout), "Рядок «\(name)» не з'явився в списку")
        for line in [firstLine, secondLine] {
            let mentions = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", line))
            XCTAssertEqual(mentions.count, 0, "У списку видно примітку («\(line)»)")
        }

        app.openSwitch(named: name)
        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає примітки на екрані перемикача")
        XCTAssertTrue(
            waitForLabel(saved, of: app.switchNoteButton),
            "Примітка на екрані перемикача «\(app.switchNoteButton.label)» замість «\(saved)»"
        )
    }

    /// Екран додавання: ввести 205 символів у примітку → у полі перші 200, лічильник «Символів: 200 з 200».
    @MainActor
    func testAddScreenNoteFieldStopsAt200Characters() throws {
        let app = XCUIApplication.launchedForTesting()
        openAddScreen(in: app)
        let field = app.addSwitchNoteField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля «Примітка» на екрані додавання")
        field.tap()

        let typed = String(repeating: "0123456789", count: 20) + "АБВГД"
        field.typeText(typed)

        XCTAssertTrue(
            waitForValue(String(typed.prefix(200)), of: field),
            "У полі \((field.value as? String ?? "").count) символів замість перших 200"
        )
        let counter = app.staticTexts[AccessibilityID.addSwitchNoteCounter]
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout), "Немає лічильника під полем примітки")
        XCTAssertTrue(waitForLabel("Символів: 200 з 200", of: counter), "Лічильник «\(counter.label)»")
    }

    // MARK: - Екран перемикача

    /// Перемикач без примітки → у картці «Додати примітку» → натиснути → поле й лічильник «0 з 200» →
    /// ввести два рядки (Return не завершує редагування) → «Готово» над клавіатурою → поле закрилося,
    /// у картці примітка з переносом; назва не змінилася.
    @MainActor
    func testAddingNoteOnSwitchScreen() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")

        let noteButton = app.switchNoteButton
        XCTAssertTrue(noteButton.waitForExistence(timeout: uiTimeout), "Немає місця для примітки в картці")
        XCTAssertEqual(noteButton.label, addNoteLabel)
        noteButton.tap()

        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на «Додати примітку» не відкрило поле")
        let counter = app.staticTexts[AccessibilityID.switchNoteEditCounter]
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout), "Немає лічильника під полем примітки")
        XCTAssertTrue(waitForLabel("Символів: 0 з 200", of: counter), "Лічильник «\(counter.label)»")

        let note = "Вранці\nі ввечері"
        field.typeText(note)
        XCTAssertTrue(waitForValue(note, of: field), "У полі «\(field.value as? String ?? "")» замість «\(note)»")
        XCTAssertTrue(field.exists, "Return завершив редагування примітки")
        XCTAssertTrue(waitForLabel("Символів: 16 з 200", of: counter), "Лічильник «\(counter.label)»")

        finishWithDone(field, in: app)
        XCTAssertTrue(waitForLabel(note, of: noteButton), "У картці «\(noteButton.label)» замість «\(note)»")
        XCTAssertEqual(app.buttons[AccessibilityID.switchNameButton].label, "Ліки", "Зміна примітки змінила назву")
    }

    /// Наявна примітка → натиснути на неї → у полі її текст → замінити → «Готово» → нова примітка.
    @MainActor
    func testEditingExistingNote() throws {
        let app = XCUIApplication.launchedForTesting()
        addNoteOnSwitchScreen("Вранці", in: app)

        app.switchNoteButton.tap()
        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на примітку не відкрило поле")
        XCTAssertEqual(field.value as? String, "Вранці", "Поле має містити поточну примітку")
        field.clearText()
        field.typeText("Ввечері")
        XCTAssertTrue(waitForValue("Ввечері", of: field), "У полі «\(field.value as? String ?? "")»")

        finishWithDone(field, in: app)
        XCTAssertTrue(waitForLabel("Ввечері", of: app.switchNoteButton), "У картці «\(app.switchNoteButton.label)»")
    }

    /// Наявна примітка → стерти весь текст → «Готово» → у картці знову «Додати примітку».
    @MainActor
    func testClearingNoteShowsAddNoteAgain() throws {
        let app = XCUIApplication.launchedForTesting()
        addNoteOnSwitchScreen("Вранці", in: app)

        app.switchNoteButton.tap()
        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на примітку не відкрило поле")
        field.clearText()
        XCTAssertTrue(waitForValue("", of: field), "Поле не очистилося: «\(field.value as? String ?? "")»")

        finishWithDone(field, in: app)
        XCTAssertTrue(waitForLabel(addNoteLabel, of: app.switchNoteButton), "У картці «\(app.switchNoteButton.label)»")
    }

    /// Екран перемикача: 199 символів, Return (перенос — 200-й символ), ще 5 символів → у полі
    /// 199 символів і перенос, лічильник «Символів: 200 з 200».
    @MainActor
    func testSwitchScreenNoteFieldStopsAt200Characters() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")
        app.switchNoteButton.tap()

        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на «Додати примітку» не відкрило поле")
        let first199 = String(repeating: "0123456789", count: 19) + "012345678"
        XCTAssertEqual(first199.count, 199)
        field.typeText(first199 + "\nАБВГД")

        XCTAssertTrue(
            waitForValue(first199 + "\n", of: field),
            "У полі \((field.value as? String ?? "").count) символів замість 199 і переносу"
        )
        let counter = app.staticTexts[AccessibilityID.switchNoteEditCounter]
        XCTAssertTrue(counter.waitForExistence(timeout: uiTimeout), "Немає лічильника під полем примітки")
        XCTAssertTrue(waitForLabel("Символів: 200 з 200", of: counter), "Лічильник «\(counter.label)»")
    }

    /// Ввести примітку без «Готово» → повернутися до списку → відкрити перемикач знову → примітку збережено.
    @MainActor
    func testNoteIsSavedWhenLeavingScreen() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")
        app.switchNoteButton.tap()

        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на «Додати примітку» не відкрило поле")
        field.typeText("Після їжі")
        XCTAssertTrue(waitForValue("Після їжі", of: field), "У полі «\(field.value as? String ?? "")»")

        app.goBackToList()
        app.openSwitch(named: "Ліки")
        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає примітки на екрані перемикача")
        XCTAssertTrue(
            waitForLabel("Після їжі", of: app.switchNoteButton),
            "Після повернення в картці «\(app.switchNoteButton.label)» замість «Після їжі»"
        )
    }

    /// Редагується примітка (без «Готово») → натиснути на назву → поле примітки закрилося, примітку
    /// збережено; поля назви й примітки одночасно не відкриті.
    @MainActor
    func testTappingNameWhileEditingNoteSavesNote() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")
        app.switchNoteButton.tap()

        let noteField = app.switchNoteEditField
        XCTAssertTrue(noteField.waitForExistence(timeout: uiTimeout), "Натискання на «Додати примітку» не відкрило поле")
        noteField.typeText("Після їжі")
        XCTAssertTrue(waitForValue("Після їжі", of: noteField), "У полі «\(noteField.value as? String ?? "")»")

        app.buttons[AccessibilityID.switchNameButton].tap()

        XCTAssertTrue(noteField.waitForNonExistence(timeout: uiTimeout), "Поле примітки не закрилося після натискання на назву")
        XCTAssertTrue(waitForLabel("Після їжі", of: app.switchNoteButton), "У картці «\(app.switchNoteButton.label)» замість «Після їжі»")
        XCTAssertFalse(noteField.exists && app.switchNameEditField.exists, "Назва й примітка редагуються одночасно")
    }

    /// Редагується назва (без «Готово») → натиснути на «Додати примітку» → поле назви закрилося, назву
    /// збережено; поля назви й примітки одночасно не відкриті.
    @MainActor
    func testTappingNoteWhileEditingNameSavesName() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")

        let nameButton = app.buttons[AccessibilityID.switchNameButton]
        nameButton.tap()
        let nameField = app.switchNameEditField
        XCTAssertTrue(nameField.waitForExistence(timeout: uiTimeout), "Натискання на назву не відкрило поле")
        nameField.clearText()
        nameField.typeText("Вітаміни")
        XCTAssertTrue(waitForValue("Вітаміни", of: nameField), "У полі «\(nameField.value as? String ?? "")»")

        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає «Додати примітку» в картці")
        app.switchNoteButton.tap()

        XCTAssertTrue(nameField.waitForNonExistence(timeout: uiTimeout), "Поле назви не закрилося після натискання на примітку")
        XCTAssertTrue(waitForLabel("Вітаміни", of: nameButton), "Назва «\(nameButton.label)» замість «Вітаміни»")
        XCTAssertFalse(nameField.exists && app.switchNoteEditField.exists, "Назва й примітка редагуються одночасно")
    }

    // MARK: - Зони натискання

    /// Екран додавання: дотик біля верхнього краю видимої рамки поля «Примітка» (у відступі над текстом)
    /// ставить фокус у поле; «Готово» → дотик біля нижнього краю рамки — так само. Як у поля «Назва»,
    /// яке відгукується по всій рамці.
    @MainActor
    func testTapNearEdgesOfAddScreenNoteFrameFocusesNote() throws {
        let app = XCUIApplication.launchedForTesting()
        openAddScreen(in: app)
        let field = app.addSwitchNoteField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля «Примітка» на екрані додавання")

        let frame = app.descendants(matching: .any).matching(identifier: AccessibilityID.addSwitchNoteFrame).firstMatch
        XCTAssertTrue(frame.waitForExistence(timeout: uiTimeout), "Немає елемента рамки поля «Примітка» (\(AccessibilityID.addSwitchNoteFrame))")
        // Рамка — увесь видимий прямокутник (не менше 56 pt, як у «Назви»), а поле — всередині неї.
        XCTAssertGreaterThanOrEqual(frame.frame.height, 56, "Рамка поля «Примітка» нижча за 56 pt: \(frame.frame)")
        XCTAssertTrue(frame.frame.insetBy(dx: -1, dy: -1).contains(field.frame), "Поле \(field.frame) не всередині рамки \(frame.frame)")
        XCTAssertFalse(app.keyboards.firstMatch.exists, "Клавіатура відкрита ще до дотику")

        frame.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 0, dy: 6)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Дотик біля верхнього краю рамки не відкрив клавіатуру")
        XCTAssertTrue(waitForKeyboardFocus(of: field), "Після дотику біля верхнього краю рамки поле «Примітка» не у фокусі")

        let done = app.noteKeyboardDoneButton
        XCTAssertTrue(done.waitForExistence(timeout: uiTimeout), "Немає кнопки «Готово» над клавіатурою")
        done.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: uiTimeout), "«Готово» не сховало клавіатуру")

        frame.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1)).withOffset(CGVector(dx: 0, dy: -6)).tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Дотик біля нижнього краю рамки не відкрив клавіатуру")
        XCTAssertTrue(waitForKeyboardFocus(of: field), "Після дотику біля нижнього краю рамки поле «Примітка» не у фокусі")
    }

    /// Екран перемикача: «Додати примітку» — зона натискання щонайменше 44 pt заввишки й на всю ширину
    /// рядка картки; дотик у тому ж рядку правіше за текст відкриває поле редагування.
    @MainActor
    func testAddNoteTouchTargetSpansCardRow() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Ліки")
        app.openSwitch(named: "Ліки")

        let noteButton = app.switchNoteButton
        XCTAssertTrue(noteButton.waitForExistence(timeout: uiTimeout), "Немає «Додати примітку» в картці")
        XCTAssertEqual(noteButton.label, addNoteLabel)
        let window = app.windows.element(boundBy: 0).frame
        let target = noteButton.frame
        XCTAssertGreaterThanOrEqual(target.height, 44, "Зона «Додати примітку» нижча за 44 pt: \(target)")
        XCTAssertGreaterThanOrEqual(target.width, window.width / 2, "Зона «Додати примітку» лише завширшки як текст: \(target), вікно \(window.width) pt")

        // Правий край вмісту картки — 16 pt відступу екрана + 20 pt відступу картки; дотик на 50 pt від краю вікна
        // лежить у картці, у рядку примітки, правіше за текст «Додати примітку».
        let rightOfText = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: window.width - 50, dy: target.midY))
        rightOfText.tap()
        XCTAssertTrue(app.switchNoteEditField.waitForExistence(timeout: uiTimeout), "Дотик у рядку примітки правіше за текст не відкрив поле")
    }

    // MARK: - Інші способи завершити редагування примітки

    /// Редагується примітка (без «Готово») → обрати інший колір → колір обрано, поле закрилося,
    /// примітку збережено.
    @MainActor
    func testChoosingColorEndsNoteEditingAndSavesNote() throws {
        let app = XCUIApplication.launchedForTesting()
        let field = startNoteEditing("Після їжі", in: app)

        // Новий перемикач — бурштиновий; «Корал» — інший колір.
        let coral = app.buttons[AccessibilityID.toneOption("coral")]
        XCTAssertTrue(coral.waitForExistence(timeout: uiTimeout), "Немає кнопки кольору «Корал»")
        XCTAssertFalse(coral.isSelected, "«Корал» уже обрано — тест не перевірить зміну кольору")
        coral.tap()

        XCTAssertTrue(waitForSelected(coral), "Натискання не обрало колір")
        assertNoteSaved("Після їжі", field: field, in: app, after: "вибору кольору")
    }

    /// Редагується примітка (без «Готово») → увімкнути лампу в картці → лампа увімкнена, поле закрилося,
    /// примітку збережено.
    @MainActor
    func testTogglingLampEndsNoteEditingAndSavesNote() throws {
        let app = XCUIApplication.launchedForTesting()
        let field = startNoteEditing("Після їжі", in: app)

        // Лампа в картці — єдиний перемикач на екрані перемикача.
        let lamp = app.windows.element(boundBy: 0).switches.firstMatch
        XCTAssertTrue(lamp.waitForExistence(timeout: uiTimeout), "Немає лампи в картці")
        XCTAssertEqual(lamp.value as? String, "0", "Новий перемикач уже увімкнений")
        lamp.tap()

        XCTAssertTrue(waitForValue("1", of: lamp), "Натискання не увімкнуло лампу")
        assertNoteSaved("Після їжі", field: field, in: app, after: "перемикання лампи")
    }

    /// Редагується примітка (без «Готово») → обрати інший значок → значок обрано, поле закрилося,
    /// примітку збережено.
    @MainActor
    func testChoosingIconEndsNoteEditingAndSavesNote() throws {
        let app = XCUIApplication.launchedForTesting()
        let field = startNoteEditing("Після їжі", in: app)

        // Новий перемикач — ✔️; 🔥 — інший значок.
        let flame = app.buttons[AccessibilityID.iconOption("🔥")]
        XCTAssertTrue(flame.waitForExistence(timeout: uiTimeout), "Немає кнопки значка 🔥")
        XCTAssertFalse(flame.isSelected, "🔥 уже обрано — тест не перевірить зміну значка")
        flame.tap()

        XCTAssertTrue(waitForSelected(flame), "Натискання не обрало значок")
        assertNoteSaved("Після їжі", field: field, in: app, after: "вибору значка")
    }

    // MARK: - Допоміжне

    /// Додає перемикач «Ліки», відкриває його, натискає «Додати примітку» й друкує `note` (без «Готово»).
    @MainActor
    private func startNoteEditing(_ note: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) -> XCUIElement {
        app.addSwitch(named: "Ліки", file: file, line: line)
        app.openSwitch(named: "Ліки", file: file, line: line)
        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає «Додати примітку» в картці", file: file, line: line)
        app.switchNoteButton.tap()
        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на «Додати примітку» не відкрило поле", file: file, line: line)
        field.typeText(note)
        XCTAssertTrue(waitForValue(note, of: field), "У полі «\(field.value as? String ?? "")»", file: file, line: line)
        return field
    }

    /// Поле примітки закрилося, у картці — збережена примітка `note`.
    @MainActor
    private func assertNoteSaved(
        _ note: String, field: XCUIElement, in app: XCUIApplication, after step: String,
        file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "Поле примітки не закрилося після \(step)", file: file, line: line)
        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає примітки в картці", file: file, line: line)
        XCTAssertTrue(
            waitForLabel(note, of: app.switchNoteButton),
            "Після \(step) у картці «\(app.switchNoteButton.label)» замість «\(note)»", file: file, line: line
        )
    }

    /// Чекає, поки елемент отримає фокус клавіатури (атрибут XCUITest `hasKeyboardFocus`).
    @MainActor
    private func waitForKeyboardFocus(of element: XCUIElement) -> Bool {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hasKeyboardFocus == true"), object: element)
        return XCTWaiter().wait(for: [expectation], timeout: uiTimeout) == .completed
    }

    /// Натискає «+» у списку і чекає, поки екран додавання покажеться повністю.
    @MainActor
    private func openAddScreen(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Немає кнопки додавання в списку", file: file, line: line)
        app.addSwitchButton.tap()
        XCTAssertTrue(app.addSwitchNameField.waitForExistence(timeout: uiTimeout), "Немає поля назви на екрані додавання", file: file, line: line)
        XCTAssertTrue(
            waitUntilHittable(app.buttons[AccessibilityID.addSwitchSaveButton]),
            "Екран додавання не показано повністю", file: file, line: line
        )
    }

    /// Натискає «Готово» над клавіатурою й чекає, поки поле редагування примітки закриється.
    @MainActor
    private func finishWithDone(_ field: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let done = app.noteKeyboardDoneButton
        XCTAssertTrue(done.waitForExistence(timeout: uiTimeout), "Немає кнопки «Готово» над клавіатурою", file: file, line: line)
        done.tap()
        XCTAssertTrue(field.waitForNonExistence(timeout: uiTimeout), "Поле примітки не закрилося після «Готово»", file: file, line: line)
        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає примітки в картці", file: file, line: line)
    }

    /// Додає перемикач «Ліки», відкриває його й додає примітку `note` через картку («Готово»).
    @MainActor
    private func addNoteOnSwitchScreen(_ note: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        app.addSwitch(named: "Ліки", file: file, line: line)
        app.openSwitch(named: "Ліки", file: file, line: line)
        XCTAssertTrue(app.switchNoteButton.waitForExistence(timeout: uiTimeout), "Немає місця для примітки в картці", file: file, line: line)
        app.switchNoteButton.tap()
        let field = app.switchNoteEditField
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Натискання на «Додати примітку» не відкрило поле", file: file, line: line)
        field.typeText(note)
        XCTAssertTrue(waitForValue(note, of: field), "У полі «\(field.value as? String ?? "")»", file: file, line: line)
        finishWithDone(field, in: app, file: file, line: line)
        XCTAssertTrue(waitForLabel(note, of: app.switchNoteButton), "У картці «\(app.switchNoteButton.label)»", file: file, line: line)
    }
}

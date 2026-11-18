import XCTest

/// Розділ «Нагадування» на екрані перемикача: рядки правил, «Додати нагадування», вікно правила
/// (аркуш знизу з «Скасувати» / «Зберегти»), видалення з вікна, напис про вимкнені сповіщення.
/// У тестовому режимі центр сповіщень — у пам'яті; заплановане видно в `pendingRemindersProbe`.
final class ReminderUITests: XCTestCase {
    /// Скільки чекати, щоб переконатися, що чогось НЕ сталося.
    private let quietPeriod: TimeInterval = 3
    private let switchName = "Газ горить"
    /// Тексти плану правила за замовчуванням («Коли увімкнено», 30 хв, з повтором) для увімкненого перемикача.
    private let defaultRulePlan = "Увімкнено вже 30 хв\nУвімкнено вже 40 хв\nУвімкнено вже 50 хв"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Нове правило

    /// «Додати нагадування» → вікно з типовими значеннями («Коли увімкнено», 30, хв, повтор увімкнено,
    /// пояснення повтору, приклад сповіщення), клавіатура сама не відкривається → «Зберегти» →
    /// вікно закрилося, у розділі один рядок «Через 30 хв, коли увімкнено · повтор».
    @MainActor
    func testNewReminderHasDefaultsAndAppearsAsRow() throws {
        let app = launchOnSwitchScreen()

        openNewReminderEditor(in: app)
        XCTAssertTrue(waitForSelected(conditionOption("on", in: app)), "За замовчуванням не обрано «Коли увімкнено»")
        XCTAssertFalse(conditionOption("off", in: app).isSelected, "«Коли вимкнено» обрано за замовчуванням")
        XCTAssertFalse(conditionOption("always", in: app).isSelected, "«Завжди» обрано за замовчуванням")
        XCTAssertTrue(waitForValue("30", of: amountField(in: app)), "Число за замовчуванням не 30: \(amountField(in: app).value ?? "nil")")
        XCTAssertTrue(waitForSelected(unitOption("minutes", in: app)), "За замовчуванням не обрано хвилини")
        XCTAssertEqual(repeatToggle(in: app).value as? String, "1", "Повтор за замовчуванням вимкнено")
        XCTAssertTrue(app.staticTexts["Ще 2 рази, кожні 10 хв"].exists, "Немає пояснення повтору «Ще 2 рази, кожні 10 хв»")
        let previewTitle = element(AccessibilityID.reminderPreviewTitle, in: app)
        XCTAssertTrue(previewTitle.waitForExistence(timeout: uiTimeout), "Немає прикладу сповіщення")
        XCTAssertTrue(previewTitle.label.hasPrefix("\u{2714}\u{FE0F}"), "Заголовок прикладу без значка ✔️: «\(previewTitle.label)»")
        XCTAssertTrue(previewTitle.label.hasSuffix(" \(switchName)"), "Заголовок прикладу без назви: «\(previewTitle.label)»")
        XCTAssertEqual(element(AccessibilityID.reminderPreviewBody, in: app).label, "Увімкнено вже 30 хв")
        XCTAssertTrue(
            stays(app.keyboards.firstMatch, withoutBecoming: "exists == true", for: quietPeriod),
            "Клавіатура відкрилася сама — поле числа не має отримувати фокус автоматично"
        )

        saveEditor(in: app)

        XCTAssertTrue(waitForRows(["Через 30 хв, коли увімкнено · повтор"], in: app), "Рядки: \(rowLabels(in: app))")
    }

    /// Нове правило: «Скасувати» після змін → вікно закрилося, рядків немає.
    @MainActor
    func testCancelNewReminderAddsNothing() throws {
        let app = launchOnSwitchScreen()

        openNewReminderEditor(in: app)
        select(conditionOption("off", in: app), what: "«Коли вимкнено»")
        cancelEditor(in: app)

        XCTAssertTrue(
            stays(app.buttons[AccessibilityID.reminderRow], withoutBecoming: "exists == true", for: quietPeriod),
            "Після «Скасувати» з'явився рядок правила"
        )
    }

    /// Зміна одиниці скидає повтор на типовий для неї: дні — вимкнено, хв і год — увімкнено, навіть
    /// якщо перед тим його вимкнули вручну. Збережене правило в днях — без « · повтор».
    @MainActor
    func testChangingUnitResetsRepeat() throws {
        let app = launchOnSwitchScreen()
        openNewReminderEditor(in: app)
        let repeatToggle = repeatToggle(in: app)

        select(unitOption("days", in: app), what: "дні")
        XCTAssertTrue(waitForValue("0", of: repeatToggle), "Після вибору днів повтор не вимкнувся")

        select(unitOption("hours", in: app), what: "години")
        XCTAssertTrue(waitForValue("1", of: repeatToggle), "Після вибору годин повтор не увімкнувся")

        flip(repeatToggle)
        XCTAssertTrue(waitForValue("0", of: repeatToggle), "Повтор не вимкнувся натисканням")
        select(unitOption("minutes", in: app), what: "хвилини")
        XCTAssertTrue(waitForValue("1", of: repeatToggle), "Після вибору хвилин повтор не повернувся до типового (увімкнено)")

        select(unitOption("days", in: app), what: "дні")
        XCTAssertTrue(waitForValue("0", of: repeatToggle), "Після вибору днів повтор не вимкнувся")
        XCTAssertEqual(element(AccessibilityID.reminderPreviewBody, in: app).label, "Увімкнено вже 30 днів")
        saveEditor(in: app)

        XCTAssertTrue(waitForRows(["Через 30 днів, коли увімкнено"], in: app), "Рядки: \(rowLabels(in: app))")
    }

    // MARK: - Наявне правило

    /// Рядок → вікно з поточними значеннями → «Коли вимкнено», години, число 2 з числової клавіатури →
    /// приклад «Вимкнено вже 2 год» → «Зберегти» → той самий єдиний рядок з новим текстом.
    @MainActor
    func testEditingReminderUpdatesRow() throws {
        let app = launchOnSwitchScreen()
        addDefaultReminder(in: app)

        openReminderRow(in: app)
        XCTAssertTrue(waitForSelected(conditionOption("on", in: app)), "У вікні правила не обрано його умову «Коли увімкнено»")
        XCTAssertTrue(waitForValue("30", of: amountField(in: app)), "У вікні правила не його число 30")
        XCTAssertTrue(element(AccessibilityID.reminderDeleteButton, in: app).exists, "У вікні наявного правила немає «Видалити нагадування»")
        select(conditionOption("off", in: app), what: "«Коли вимкнено»")
        select(unitOption("hours", in: app), what: "години")
        replaceAmount(with: "2", in: app)
        XCTAssertTrue(
            waitForLabel("Вимкнено вже 2 год", of: element(AccessibilityID.reminderPreviewBody, in: app)),
            "Приклад сповіщення не оновився: «\(element(AccessibilityID.reminderPreviewBody, in: app).label)»"
        )
        saveEditor(in: app)

        XCTAssertTrue(waitForRows(["Через 2 год, коли вимкнено · повтор"], in: app), "Рядки: \(rowLabels(in: app))")
    }

    /// Поле числа — числова клавіатура: є цифри, немає літер.
    @MainActor
    func testAmountFieldUsesNumberPad() throws {
        let app = launchOnSwitchScreen()
        openNewReminderEditor(in: app)

        tapAtTrailingEdge(amountField(in: app))
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: uiTimeout), "Натискання на поле числа не відкрило клавіатуру")
        XCTAssertTrue(keyboard.keys["5"].exists, "На клавіатурі немає цифр")
        for letter in ["q", "a", "й", "ф"] {
            XCTAssertFalse(keyboard.keys[letter].exists, "Клавіатура не числова: є клавіша «\(letter)»")
        }
    }

    /// Наявне правило: змінити умову й одиницю → «Скасувати» → рядок не змінився.
    @MainActor
    func testCancelEditingKeepsReminder() throws {
        let app = launchOnSwitchScreen()
        addDefaultReminder(in: app)

        openReminderRow(in: app)
        select(conditionOption("always", in: app), what: "«Завжди»")
        select(unitOption("days", in: app), what: "дні")
        cancelEditor(in: app)

        XCTAssertTrue(waitForRows(["Через 30 хв, коли увімкнено · повтор"], in: app), "Рядки: \(rowLabels(in: app))")
        XCTAssertTrue(
            stays(app.buttons[AccessibilityID.reminderRow].firstMatch, withoutBecoming: "label != 'Через 30 хв, коли увімкнено · повтор'", for: quietPeriod),
            "Рядок змінився після «Скасувати»"
        )
    }

    /// Рядок → «Видалити нагадування» → вікно закрилося, рядка немає, «Додати нагадування» на місці,
    /// заплановані сповіщення правила прибрано.
    @MainActor
    func testDeletingReminderFromEditor() throws {
        let app = launchOnSwitchScreen()
        addDefaultReminder(in: app)
        flip(app.switches[AccessibilityID.switchScreenToggle])
        XCTAssertTrue(waitForProbe(defaultRulePlan, in: app), "Після увімкнення не заплановано: «\(probeValue(in: app))»")

        openReminderRow(in: app)
        let delete = element(AccessibilityID.reminderDeleteButton, in: app)
        reveal(delete, in: app)
        delete.tap()

        XCTAssertTrue(
            app.buttons[AccessibilityID.reminderEditorSaveButton].waitForNonExistence(timeout: uiTimeout),
            "Вікно правила не закрилося після видалення"
        )
        XCTAssertTrue(app.buttons[AccessibilityID.reminderRow].waitForNonExistence(timeout: uiTimeout), "Рядок правила лишився")
        XCTAssertTrue(app.buttons[AccessibilityID.addReminderButton].exists, "Немає «Додати нагадування»")
        XCTAssertTrue(waitForEmptyProbe(in: app), "Після видалення правила лишилися заплановані: «\(probeValue(in: app))»")
    }

    // MARK: - План стежить за змінами

    /// Правило «Коли увімкнено»: перемикач вимкнено — нічого; увімкнули на екрані перемикача — три
    /// нагадування; вимкнули — нічого; увімкнули в списку — знову три.
    @MainActor
    func testPlanFollowsSwitchState() throws {
        let app = launchOnSwitchScreen()
        addDefaultReminder(in: app)
        XCTAssertTrue(waitForEmptyProbe(in: app), "Перемикач вимкнено, а заплановано: «\(probeValue(in: app))»")

        let toggle = app.switches[AccessibilityID.switchScreenToggle]
        XCTAssertTrue(toggle.waitForExistence(timeout: uiTimeout), "Немає перемикача на екрані перемикача")
        flip(toggle)
        XCTAssertTrue(waitForProbe(defaultRulePlan, in: app), "Після увімкнення: «\(probeValue(in: app))»")

        flip(toggle)
        XCTAssertTrue(waitForEmptyProbe(in: app), "Після вимкнення лишилося: «\(probeValue(in: app))»")

        app.goBackToList()
        let rowToggle = app.row(named: switchName).switches[AccessibilityID.switchRowToggle]
        XCTAssertTrue(rowToggle.waitForExistence(timeout: uiTimeout), "Немає перемикача в рядку списку")
        rowToggle.tap()
        XCTAssertTrue(waitForProbe(defaultRulePlan, in: app), "Після увімкнення в списку: «\(probeValue(in: app))»")
    }

    /// Зміна правила одразу змінює план: «Коли увімкнено» на вимкненому перемикачі — нічого;
    /// стало «Завжди, 3 дні» — «Не перемикали вже 3 дні».
    @MainActor
    func testEditingReminderReplansNotifications() throws {
        let app = launchOnSwitchScreen()
        addDefaultReminder(in: app)
        XCTAssertTrue(waitForEmptyProbe(in: app), "Перемикач вимкнено, а заплановано: «\(probeValue(in: app))»")

        makeDefaultReminderAlwaysThreeDays(in: app)

        XCTAssertTrue(waitForProbe("Не перемикали вже 3 дні", in: app), "Після зміни правила: «\(probeValue(in: app))»")
    }

    /// Видалили перемикач у списку — його нагадування прибрано з плану.
    @MainActor
    func testDeletingSwitchClearsItsReminders() throws {
        let app = launchOnSwitchScreen()
        addDefaultReminder(in: app)
        makeDefaultReminderAlwaysThreeDays(in: app)
        XCTAssertTrue(waitForProbe("Не перемикали вже 3 дні", in: app), "Не заплановано: «\(probeValue(in: app))»")

        app.goBackToList()
        app.row(named: switchName).revealTrailingSwipeActions()
        let deleteAction = app.buttons["Видалити"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: uiTimeout), "Після свайпу немає кнопки «Видалити»")
        deleteAction.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: uiTimeout), "Немає підтвердження видалення")
        alert.buttons["Видалити"].tap()
        XCTAssertTrue(app.row(named: switchName).waitForNonExistence(timeout: uiTimeout), "Рядок перемикача лишився")

        XCTAssertTrue(waitForEmptyProbe(in: app), "Після видалення перемикача лишилося: «\(probeValue(in: app))»")
    }

    // MARK: - Дозвіл

    /// Дозвіл відмовлено → після збереження правила в розділі «Сповіщення вимкнено» і «Відкрити Параметри».
    @MainActor
    func testDeniedPermissionShowsNoticeAndSettingsButton() throws {
        let app = launchOnSwitchScreen(arguments: [LaunchArgument.notificationsDenied])
        addDefaultReminder(in: app)

        let notice = element(AccessibilityID.notificationsDisabledNotice, in: app)
        XCTAssertTrue(notice.waitForExistence(timeout: uiTimeout), "Немає напису про вимкнені сповіщення")
        XCTAssertEqual(notice.label, "Сповіщення вимкнено")
        let settings = app.buttons[AccessibilityID.openNotificationSettingsButton]
        XCTAssertTrue(settings.waitForExistence(timeout: uiTimeout), "Немає кнопки «Відкрити Параметри»")
        XCTAssertEqual(settings.label, "Відкрити Параметри")
    }

    /// Дозвіл надано → після збереження правила напису й кнопки немає.
    @MainActor
    func testAllowedPermissionShowsNoNotice() throws {
        let app = launchOnSwitchScreen(arguments: [LaunchArgument.notificationsAllowed])
        addDefaultReminder(in: app)

        XCTAssertTrue(
            stays(element(AccessibilityID.notificationsDisabledNotice, in: app), withoutBecoming: "exists == true", for: quietPeriod),
            "Дозвіл надано, а показано «Сповіщення вимкнено»"
        )
        XCTAssertFalse(app.buttons[AccessibilityID.openNotificationSettingsButton].exists, "Дозвіл надано, а є «Відкрити Параметри»")
    }

    // MARK: - Кроки

    /// Запускає застосунок, додає перемикач «Газ горить» і відкриває його екран.
    @MainActor
    private func launchOnSwitchScreen(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication.launchedForTesting(arguments: arguments)
        app.addSwitch(named: switchName)
        app.openSwitch(named: switchName)
        return app
    }

    @MainActor
    private func openNewReminderEditor(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let add = app.buttons[AccessibilityID.addReminderButton]
        XCTAssertTrue(add.waitForExistence(timeout: uiTimeout), "Немає кнопки «Додати нагадування»", file: file, line: line)
        XCTAssertEqual(add.label, "Додати нагадування", file: file, line: line)
        reveal(add, in: app, file: file, line: line)
        add.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.reminderEditorSaveButton].waitForExistence(timeout: uiTimeout),
            "Вікно правила не відкрилося", file: file, line: line
        )
    }

    /// Додає правило з типовими значеннями й чекає на його рядок.
    @MainActor
    private func addDefaultReminder(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openNewReminderEditor(in: app, file: file, line: line)
        saveEditor(in: app, file: file, line: line)
        XCTAssertTrue(
            waitForRows(["Через 30 хв, коли увімкнено · повтор"], in: app),
            "Рядок нового правила не з'явився: \(rowLabels(in: app))", file: file, line: line
        )
    }

    /// Правило з типовими значеннями стає «Завжди, 3 дні».
    @MainActor
    private func makeDefaultReminderAlwaysThreeDays(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        openReminderRow(in: app, file: file, line: line)
        select(conditionOption("always", in: app), what: "«Завжди»", file: file, line: line)
        select(unitOption("days", in: app), what: "дні", file: file, line: line)
        replaceAmount(with: "3", in: app, file: file, line: line)
        saveEditor(in: app, file: file, line: line)
        XCTAssertTrue(
            waitForRows(["Через 3 дні без перемикань"], in: app),
            "Рядок не оновився: \(rowLabels(in: app))", file: file, line: line
        )
    }

    @MainActor
    private func openReminderRow(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons[AccessibilityID.reminderRow].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: uiTimeout), "Немає рядка правила", file: file, line: line)
        reveal(row, in: app, file: file, line: line)
        row.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.reminderEditorSaveButton].waitForExistence(timeout: uiTimeout),
            "Натискання на рядок не відкрило вікно правила", file: file, line: line
        )
    }

    /// «Зберегти» вгорі аркуша — над клавіатурою, якщо вона відкрита.
    @MainActor
    private func saveEditor(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let save = app.buttons[AccessibilityID.reminderEditorSaveButton]
        XCTAssertTrue(save.isEnabled, "«Зберегти» недоступна", file: file, line: line)
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: uiTimeout), "Вікно правила не закрилося після «Зберегти»", file: file, line: line)
    }

    @MainActor
    private func cancelEditor(in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let cancel = app.buttons[AccessibilityID.reminderEditorCancelButton]
        XCTAssertTrue(cancel.waitForExistence(timeout: uiTimeout), "Немає «Скасувати» у вікні правила", file: file, line: line)
        cancel.tap()
        XCTAssertTrue(
            app.buttons[AccessibilityID.reminderEditorSaveButton].waitForNonExistence(timeout: uiTimeout),
            "Вікно правила не закрилося після «Скасувати»", file: file, line: line
        )
    }

    /// Стирає число в полі й вводить нове з екранної числової клавіатури.
    @MainActor
    private func replaceAmount(with text: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let field = amountField(in: app)
        XCTAssertTrue(field.waitForExistence(timeout: uiTimeout), "Немає поля числа", file: file, line: line)
        tapAtTrailingEdge(field)
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: uiTimeout), "Клавіатура не відкрилася", file: file, line: line)
        field.clearText()
        field.typeText(text)
        XCTAssertTrue(waitForValue(text, of: field), "У полі числа «\(field.value ?? "nil")» замість «\(text)»", file: file, line: line)
    }

    /// Натискає біля правого краю поля: курсор стає в кінець тексту, тож `clearText()` стирає все.
    @MainActor
    private func tapAtTrailingEdge(_ field: XCUIElement) {
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    }

    /// Обирає кнопку-варіант і чекає, поки вона стане вибраною.
    @MainActor
    private func select(_ option: XCUIElement, what: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(option.waitForExistence(timeout: uiTimeout), "Немає варіанта \(what)", file: file, line: line)
        option.tap()
        XCTAssertTrue(waitForSelected(option), "Натискання не обрало \(what)", file: file, line: line)
    }

    /// Перемикає `UISwitch`/`Toggle`: натискає по правому краю, де сам перемикач (не підпис).
    @MainActor
    private func flip(_ toggle: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(toggle.waitForExistence(timeout: uiTimeout), "Немає перемикача", file: file, line: line)
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    /// Прокручує екран (жестом над клавіатурою, якщо вона відкрита), доки елемент не стане доступним для натискання.
    @MainActor
    private func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<5 where !element.isHittable {
            if app.buttons[AccessibilityID.reminderEditorSaveButton].exists {
                app.windows.element(boundBy: 0).swipeUp()
            } else {
                app.scrollSwitchScreenUpAboveKeyboard(file: file, line: line)
            }
        }
        XCTAssertTrue(element.isHittable, "Елемент «\(element.label)» не видно навіть після прокрутки", file: file, line: line)
    }

    @MainActor
    private func conditionOption(_ condition: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons[AccessibilityID.reminderConditionOption(condition)]
    }

    @MainActor
    private func unitOption(_ unit: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons[AccessibilityID.reminderUnitOption(unit)]
    }

    @MainActor
    private func amountField(in app: XCUIApplication) -> XCUIElement {
        app.textFields[AccessibilityID.reminderAmountField]
    }

    @MainActor
    private func repeatToggle(in app: XCUIApplication) -> XCUIElement {
        app.switches[AccessibilityID.reminderRepeatToggle]
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func rowLabels(in app: XCUIApplication) -> [String] {
        app.buttons.matching(identifier: AccessibilityID.reminderRow).allElementsBoundByIndex.map(\.label)
    }

    /// Чекає, поки рядки правил стануть саме такими (у порядку на екрані).
    @MainActor
    private func waitForRows(_ expected: [String], in app: XCUIApplication) -> Bool {
        let deadline = Date.now.addingTimeInterval(uiTimeout)
        repeat {
            if rowLabels(in: app) == expected { return true }
            _ = app.buttons[AccessibilityID.reminderRow].waitForExistence(timeout: 0.5)
        } while Date.now < deadline
        return rowLabels(in: app) == expected
    }

    // MARK: - Заплановані сповіщення (центр у пам'яті)

    @MainActor
    private func probe(in app: XCUIApplication) -> XCUIElement {
        let probe = element(AccessibilityID.pendingRemindersProbe, in: app)
        XCTAssertTrue(probe.waitForExistence(timeout: uiTimeout), "Немає елемента pendingRemindersProbe (тестовий режим)")
        return probe
    }

    @MainActor
    private func probeValue(in app: XCUIApplication) -> String {
        (element(AccessibilityID.pendingRemindersProbe, in: app).value as? String) ?? "nil"
    }

    @MainActor
    private func waitForProbe(_ expected: String, in app: XCUIApplication) -> Bool {
        waitForValue(expected, of: probe(in: app))
    }

    @MainActor
    private func waitForEmptyProbe(in app: XCUIApplication) -> Bool {
        waitForEmptyValue(of: probe(in: app))
    }
}

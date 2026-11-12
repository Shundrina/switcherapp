import XCTest

/// Онбординг у тестовому режимі (`-UITesting -UITestingShowOnboarding`).
final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Три сторінки «Далі» → «Далі»; на третій — «Зайве — геть» і «Почати»; «Почати» показує список.
    @MainActor
    func testThreePagesThenStartShowsList() throws {
        let app = XCUIApplication.launchedForTesting(showOnboarding: true)

        XCTAssertTrue(waitUntilHittable(app.staticTexts["Клац — і спокій"]), "Перша сторінка не показана")
        app.buttons["Далі"].tap()

        XCTAssertTrue(waitUntilHittable(app.staticTexts["Пам'ятає за вас"]), "Друга сторінка не показана")
        app.buttons["Далі"].tap()

        XCTAssertTrue(waitUntilHittable(app.staticTexts["Зайве — геть"]), "Третя сторінка не показана")
        let start = app.buttons["Почати"]
        XCTAssertTrue(start.waitForExistence(timeout: uiTimeout), "На останній сторінці немає «Почати»")
        XCTAssertFalse(app.buttons["Далі"].exists, "Після третьої сторінки є ще одна")
        start.tap()

        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Після «Почати» не показано список")
        XCTAssertTrue(app.staticTexts["Зайве — геть"].waitForNonExistence(timeout: uiTimeout), "Онбординг не зник")
    }

    /// «Пропустити» на першій сторінці одразу показує список.
    @MainActor
    func testSkipShowsList() throws {
        let app = XCUIApplication.launchedForTesting(showOnboarding: true)

        let skip = app.buttons["Пропустити"]
        XCTAssertTrue(skip.waitForExistence(timeout: uiTimeout), "Онбординг не показано")
        skip.tap()

        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Після «Пропустити» не показано список")
        XCTAssertTrue(skip.waitForNonExistence(timeout: uiTimeout), "Онбординг не зник")
    }
}

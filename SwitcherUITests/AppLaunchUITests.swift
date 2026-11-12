import XCTest

final class AppLaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunches() throws {
        let app = XCUIApplication.launchedForTesting()
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// `-UITesting`: онбординг пропущено, одразу порожній список.
    @MainActor
    func testUITestingSkipsOnboardingAndStartsEmpty() throws {
        let app = XCUIApplication.launchedForTesting()

        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Список не показано")
        XCTAssertFalse(app.buttons["Пропустити"].exists, "Показано онбординг")
        XCTAssertEqual(app.cells.count, 0, "Сховище не порожнє")
    }

    /// `-UITesting`: сховище лише в пам'яті — перемикач, доданий до перезапуску, після перезапуску зникає.
    @MainActor
    func testUITestingStoreIsEmptyAfterRelaunch() throws {
        let app = XCUIApplication.launchedForTesting()
        app.addSwitch(named: "Праска вимкнена")

        app.terminate()
        app.launch()

        XCTAssertTrue(app.addSwitchButton.waitForExistence(timeout: uiTimeout), "Список не показано після перезапуску")
        XCTAssertFalse(app.row(named: "Праска вимкнена").exists, "Перемикач зберігся між запусками")
        XCTAssertEqual(app.cells.count, 0, "Сховище не порожнє після перезапуску")
    }
}

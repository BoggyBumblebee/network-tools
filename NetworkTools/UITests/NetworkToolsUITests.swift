import XCTest

final class NetworkToolsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsInfoTabByDefault() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.windows.element(boundBy: 0).waitForExistence(timeout: 5))
        XCTAssertTrue(app.popUpButtons["info.interfacePicker"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Interface Information"].exists)
        XCTAssertTrue(app.staticTexts["Transfer Statistics"].exists)
    }

    @MainActor
    func testPingTabValidationUpdatesInteractiveState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-select-tab=ping"]
        app.launch()

        let destinationField = app.textFields["ping.destination"]
        let countField = app.textFields["ping.count"]
        let unlimitedCheckbox = app.checkBoxes["ping.unlimited"]
        let startButton = app.buttons["ping.primaryAction"]

        XCTAssertTrue(destinationField.waitForExistence(timeout: 2))
        XCTAssertTrue(countField.exists)
        XCTAssertTrue(unlimitedCheckbox.exists)
        XCTAssertTrue(startButton.exists)
        XCTAssertFalse(startButton.isEnabled)

        replaceText(in: destinationField, with: "127.0.0.1")

        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(countField.isEnabled)

        unlimitedCheckbox.click()

        XCTAssertFalse(countField.isEnabled)
        XCTAssertTrue(startButton.isEnabled)
    }

    @MainActor
    func testPortScanTabValidationUpdatesInteractiveState() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-select-tab=portscan"]
        app.launch()

        let destinationField = app.textFields["portscan.destination"]
        let fromPortField = app.textFields["portscan.fromPort"]
        let toPortField = app.textFields["portscan.toPort"]
        let scanAllCheckbox = app.checkBoxes["portscan.scanAll"]
        let startButton = app.buttons["portscan.primaryAction"]

        XCTAssertTrue(destinationField.waitForExistence(timeout: 2))
        XCTAssertTrue(fromPortField.exists)
        XCTAssertTrue(toPortField.exists)
        XCTAssertTrue(scanAllCheckbox.exists)
        XCTAssertTrue(startButton.exists)
        XCTAssertFalse(startButton.isEnabled)

        replaceText(in: destinationField, with: "127.0.0.1")
        replaceText(in: fromPortField, with: "9000")
        replaceText(in: toPortField, with: "1000")

        XCTAssertFalse(startButton.isEnabled)

        scanAllCheckbox.click()

        XCTAssertFalse(fromPortField.isEnabled)
        XCTAssertFalse(toPortField.isEnabled)
        XCTAssertTrue(startButton.isEnabled)
    }

    @MainActor
    private func replaceText(in element: XCUIElement, with text: String) {
        element.click()
        element.typeKey("a", modifierFlags: .command)
        element.typeText(text)
    }
}

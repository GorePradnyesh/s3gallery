import XCTest

final class FileActionFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    private func navigateToBucket() {
        let bucket = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucket.waitForExistence(timeout: 5) {
            bucket.tap()
        }
    }

    private func findFile(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '\(name)'")).firstMatch
    }

    // MARK: - Selection Mode

    func testSelectButtonEntersSelectionMode() {
        navigateToBucket()
        let selectButton = app.buttons["Select"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5))
        selectButton.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2))
    }

    func testDoneButtonExitsSelectionMode() {
        navigateToBucket()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        app.buttons["Select"].tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2))
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 2))
    }

    func testSelectButtonIsNotVisibleAtRoot() {
        // At root (bucket list), there should be no Select button
        let selectButton = app.buttons["Select"]
        // Wait for the bucket list to load
        let _ = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
            .waitForExistence(timeout: 5)
        XCTAssertFalse(selectButton.exists)
    }

    func testSelectionActionBarAppearsWhenFileSelected() {
        navigateToBucket()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        app.buttons["Select"].tap()

        // Tap a file to select it
        let file = findFile(named: "sunset.jpg")
        if file.waitForExistence(timeout: 5) {
            file.tap()
            // The selection action bar should appear
            XCTAssertTrue(app.otherElements["SelectionActionBar"].waitForExistence(timeout: 2))
        }
    }

    // MARK: - Context Menu

    func testLongPressFileShowsContextMenu() {
        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)

        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Open In"].exists)
        XCTAssertTrue(app.buttons["Copy to Files"].exists)
    }

    func testLongPressImageShowsSaveToPhotos() {
        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)

        // Images show Save to Photos
        XCTAssertTrue(app.buttons["Save to Photos"].waitForExistence(timeout: 3))
    }

    func testContextMenuSelectEntersSelectionMode() {
        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)

        let selectInMenu = app.buttons["Select"]
        XCTAssertTrue(selectInMenu.waitForExistence(timeout: 3))
        selectInMenu.tap()

        // Should now be in selection mode (Done button visible)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2))
    }

    // MARK: - Share Sheet (requires --mock-file-action)

    func testShareActionPresentsSheet() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-file-action"]
        app.launch()

        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 3))
        app.buttons["Share"].tap()

        // System share sheet appears — detect its close button
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    }

    func testOpenInActionPresentsSheet() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-file-action"]
        app.launch()

        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Open In"].waitForExistence(timeout: 3))
        app.buttons["Open In"].tap()

        // Both Share and Open In use the same UIActivityViewController
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    }

    // MARK: - Viewer Share Button

    func testViewerHasShareButton() {
        app.terminate()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-file-action"]
        app.launch()

        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.tap()

        let shareButton = app.buttons["Share"]
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
    }
}

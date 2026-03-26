import XCTest

// MARK: - Default args (no pre-downloaded file)

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
        if bucket.waitForExistence(timeout: 5) { bucket.tap() }
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
        let selectButton = app.buttons["Select"]
        let _ = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
            .waitForExistence(timeout: 5)
        XCTAssertFalse(selectButton.exists)
    }

    func testSelectionActionBarAppearsWhenFileSelected() {
        navigateToBucket()
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        app.buttons["Select"].tap()

        let file = findFile(named: "sunset.jpg")
        XCTAssertTrue(file.waitForExistence(timeout: 5))
        file.tap()
        XCTAssertTrue(app.otherElements["SelectionActionBar"].waitForExistence(timeout: 2))
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

        let selectInMenu = app.buttons["context-menu-select"]
        XCTAssertTrue(selectInMenu.waitForExistence(timeout: 3))
        selectInMenu.tap()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 2))
    }
}

// MARK: - File action sheets (--mock-file-action pre-downloads the file)

final class FileActionSheetFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-file-action"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    private func navigateToBucket() {
        let bucket = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucket.waitForExistence(timeout: 5) { bucket.tap() }
    }

    private func findFile(named name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '\(name)'")).firstMatch
    }

    func testShareActionPresentsSheet() {
        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 3))
        app.buttons["Share"].tap()

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    }

    func testOpenInActionPresentsSheet() {
        navigateToBucket()
        let file = findFile(named: "sunset.jpg")
        guard file.waitForExistence(timeout: 5) else {
            XCTFail("sunset.jpg not found in bucket")
            return
        }

        file.press(forDuration: 1.2)
        XCTAssertTrue(app.buttons["Open In"].waitForExistence(timeout: 3))
        app.buttons["Open In"].tap()

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
    }

    func testViewerHasShareButton() {
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

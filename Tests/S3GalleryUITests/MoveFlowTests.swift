import XCTest

// MARK: - Happy path and browsing flows

final class MoveFlowTests: XCTestCase {
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

    private func enterSelectionMode() {
        let select = app.buttons["Select"]
        if select.waitForExistence(timeout: 5) { select.tap() }
    }

    private func selectFile(named name: String) {
        let file = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] '\(name)'")).firstMatch
        if file.waitForExistence(timeout: 5) { file.tap() }
    }

    /// Full sequence to open the Move sheet with autumn.jpg selected.
    private func openMoveSheet() {
        navigateToBucket()
        enterSelectionMode()
        selectFile(named: "autumn.jpg")
        XCTAssertTrue(app.otherElements["SelectionActionBar"].waitForExistence(timeout: 3))
        app.buttons["Move"].tap()
    }

    // MARK: - Tests

    func testMoveButtonAppearsInSelectionMode() {
        navigateToBucket()
        enterSelectionMode()
        selectFile(named: "sunset.jpg")

        XCTAssertTrue(app.otherElements["SelectionActionBar"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Move"].exists)
    }

    func testMoveSheetOpens() {
        openMoveSheet()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["New Folder"].exists)
        let banner = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Cross-bucket'")).firstMatch
        XCTAssertTrue(banner.exists)
    }

    func testMoveHereDisabledAtSourcePrefix() {
        // Source prefix is "" (bucket root). Picker also starts at "". Same location → disabled.
        openMoveSheet()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["move-here-button"].isEnabled)
    }

    func testFolderListAppearsInPicker() {
        openMoveSheet()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 5))
        let photos = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        let videos = app.buttons.matching(NSPredicate(format: "label CONTAINS 'videos'")).firstMatch
        XCTAssertTrue(photos.exists)
        XCTAssertTrue(videos.exists)
    }

    func testMoveHereEnabledAfterNavigatingToFolder() {
        openMoveSheet()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 5))
        let photosFolder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        XCTAssertTrue(photosFolder.waitForExistence(timeout: 3))
        photosFolder.tap()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["move-here-button"].isEnabled)
    }

    func testBreadcrumbNavigationInPicker() {
        openMoveSheet()

        // Navigate into photos/ (Move Here becomes enabled)
        let photosFolder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        XCTAssertTrue(photosFolder.waitForExistence(timeout: 5))
        photosFolder.tap()
        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["move-here-button"].isEnabled)

        // Tap bucket breadcrumb to go back to root (same as source → disabled again)
        let bucketCrumb = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(bucketCrumb.waitForExistence(timeout: 3))
        bucketCrumb.tap()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["move-here-button"].isEnabled)
    }

    func testSuccessfulMoveExitsSelectionAndRefreshes() {
        openMoveSheet()

        let photosFolder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        XCTAssertTrue(photosFolder.waitForExistence(timeout: 5))
        photosFolder.tap()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
        app.buttons["move-here-button"].tap()

        // Sheet should auto-dismiss and selection mode should be exited
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["move-here-button"].exists)
    }

    func testMoveCancelDismissesSheet() {
        openMoveSheet()

        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        XCTAssertFalse(app.buttons["move-here-button"].waitForExistence(timeout: 3))
        // Browser is back — bucket content should be visible
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'autumn.jpg'")).firstMatch.exists)
    }

    func testCreateFolderInPickerOpensSheet() {
        openMoveSheet()

        XCTAssertTrue(app.buttons["New Folder"].waitForExistence(timeout: 5))
        app.buttons["New Folder"].tap()

        XCTAssertTrue(app.buttons["create-folder-button"].waitForExistence(timeout: 3))
    }
}

// MARK: - Conflict detection flows

final class MoveConflictFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-move-conflict"]
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

    /// Brings up the Move sheet with autumn.jpg selected, then navigates into photos/.
    /// The mock returns autumn.jpg at photos/ too, so tapping "Move Here" will trigger a conflict.
    private func openMoveSheetAtConflictDestination() {
        navigateToBucket()
        app.buttons["Select"].tap()
        let file = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'autumn.jpg'")).firstMatch
        if file.waitForExistence(timeout: 5) { file.tap() }
        XCTAssertTrue(app.otherElements["SelectionActionBar"].waitForExistence(timeout: 3))
        app.buttons["Move"].tap()
        let photosFolder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        if photosFolder.waitForExistence(timeout: 5) { photosFolder.tap() }
        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
    }

    // MARK: - Tests

    func testMoveConflictAlertAppears() {
        openMoveSheetAtConflictDestination()
        app.buttons["move-here-button"].tap()

        XCTAssertTrue(app.alerts["Overwrite Files?"].waitForExistence(timeout: 5))
    }

    func testMoveConflictCancelReturnsToBrowsing() {
        openMoveSheetAtConflictDestination()
        app.buttons["move-here-button"].tap()

        XCTAssertTrue(app.alerts["Overwrite Files?"].waitForExistence(timeout: 5))
        app.alerts["Overwrite Files?"].buttons["Cancel"].tap()

        // Alert dismissed — picker still open
        XCTAssertFalse(app.alerts["Overwrite Files?"].exists)
        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
    }

    func testMoveConflictOverwriteProceeds() {
        openMoveSheetAtConflictDestination()
        app.buttons["move-here-button"].tap()

        XCTAssertTrue(app.alerts["Overwrite Files?"].waitForExistence(timeout: 5))
        app.alerts["Overwrite Files?"].buttons["Overwrite"].tap()

        // Move proceeds and sheet auto-dismisses
        XCTAssertTrue(app.buttons["Select"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["move-here-button"].exists)
    }
}

// MARK: - Failure flows

final class MoveFailureFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-copy-failure"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Helpers

    private func triggerMoveFailure() {
        let bucket = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucket.waitForExistence(timeout: 5) { bucket.tap() }
        app.buttons["Select"].tap()
        let file = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'autumn.jpg'")).firstMatch
        if file.waitForExistence(timeout: 5) { file.tap() }
        XCTAssertTrue(app.otherElements["SelectionActionBar"].waitForExistence(timeout: 3))
        app.buttons["Move"].tap()
        let photosFolder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        if photosFolder.waitForExistence(timeout: 5) { photosFolder.tap() }
        XCTAssertTrue(app.buttons["move-here-button"].waitForExistence(timeout: 3))
        app.buttons["move-here-button"].tap()
    }

    // MARK: - Tests

    func testMoveFailureShowsFailureList() {
        triggerMoveFailure()

        XCTAssertTrue(app.buttons["move-sheet-done-button"].waitForExistence(timeout: 5))
        let failedFileName = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'autumn.jpg'")
        ).firstMatch
        XCTAssertTrue(failedFileName.exists)
    }

    func testMoveFailureDoneButtonDismissesSheet() {
        triggerMoveFailure()

        XCTAssertTrue(app.buttons["move-sheet-done-button"].waitForExistence(timeout: 5))
        app.buttons["move-sheet-done-button"].tap()

        // Sheet gone — back in browser
        XCTAssertFalse(app.buttons["move-sheet-done-button"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'autumn.jpg'")).firstMatch.exists)
    }
}

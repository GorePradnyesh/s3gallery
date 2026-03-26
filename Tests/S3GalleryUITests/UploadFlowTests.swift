import XCTest

// MARK: - Default (writable bucket, no auto-selection)

final class UploadFlowTests: XCTestCase {
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

    func testUploadButtonAppearsForWritableBucket() {
        navigateToTestBucket()
        let uploadButton = app.buttons["Upload file"]
        XCTAssertTrue(uploadButton.waitForExistence(timeout: 5))
    }

    func testUploadSheetOpensOnTapOfUploadButton() {
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Photo Library"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Files"].exists)
    }

    func testUploadSheetCancelDismissesSheet() {
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Photo Library"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Photo Library"].exists)
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) { bucketCell.tap() }
    }

    private func openUploadSheet() {
        let uploadButton = app.buttons["Upload file"]
        if uploadButton.waitForExistence(timeout: 5) { uploadButton.tap() }
    }
}

// MARK: - Read-only bucket

final class UploadReadOnlyFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-read-only"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testReadOnlyBucketShowsLockIcon() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) { bucketCell.tap() }

        let lockIcon = app.buttons["Read only bucket"]
        XCTAssertTrue(lockIcon.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Upload file"].exists)
    }
}

// MARK: - Staging screen (--auto-stage pre-selects files)

final class UploadStagingFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--auto-stage"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testStagingScreenShowsSelectedFiles() {
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.staticTexts["photo1.jpg"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["document.pdf"].exists)
    }

    func testStagingScreenShowsUploadButton() {
        navigateToTestBucket()
        openUploadSheet()

        let uploadBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Upload'")).element(boundBy: 0)
        XCTAssertTrue(uploadBtn.waitForExistence(timeout: 3))
    }

    func testStagingCancelDismissesSheet() {
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.staticTexts["photo1.jpg"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) { bucketCell.tap() }
    }

    private func openUploadSheet() {
        let uploadButton = app.buttons["Upload file"]
        if uploadButton.waitForExistence(timeout: 5) { uploadButton.tap() }
    }
}

// MARK: - Success flow (--auto-upload triggers upload immediately)

final class UploadSuccessFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--auto-upload"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testUploadSuccessShowsCompletionBanner() {
        navigateToTestBucket()
        openUploadSheet()

        let banner = app.staticTexts["1 file uploaded"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testUploadSuccessDoneButtonDismissesSheet() {
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Done"].exists)
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) { bucketCell.tap() }
    }

    private func openUploadSheet() {
        let uploadButton = app.buttons["Upload file"]
        if uploadButton.waitForExistence(timeout: 5) { uploadButton.tap() }
    }
}

// MARK: - Failure flow (--auto-upload + --mock-upload-failure)

final class UploadFailureFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login",
                               "--auto-upload", "--mock-upload-failure"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testUploadFailureShowsFailedSection() {
        navigateToTestBucket()
        openUploadSheet()

        let summary = app.staticTexts["0 of 1 uploaded"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testUploadFailureDoneButtonDismissesSheet() {
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Done"].exists)
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) { bucketCell.tap() }
    }

    private func openUploadSheet() {
        let uploadButton = app.buttons["Upload file"]
        if uploadButton.waitForExistence(timeout: 5) { uploadButton.tap() }
    }
}

import XCTest

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

    // MARK: - Toolbar state

    func testUploadButtonAppearsForWritableBucket() {
        navigateToTestBucket()
        let uploadButton = app.buttons["Upload file"]
        XCTAssertTrue(uploadButton.waitForExistence(timeout: 5))
    }

    func testReadOnlyBucketShowsLockIcon() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--mock-read-only"]
        app.terminate()
        app.launch()

        navigateToTestBucket()
        let lockIcon = app.buttons["Read only bucket"]
        XCTAssertTrue(lockIcon.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Upload file"].exists)
    }

    // MARK: - Sheet presentation

    func testUploadSheetOpensOnTapOfUploadButton() {
        navigateToTestBucket()
        let uploadButton = app.buttons["Upload file"]
        XCTAssertTrue(uploadButton.waitForExistence(timeout: 5))
        uploadButton.tap()

        XCTAssertTrue(app.buttons["Photo Library"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Files"].exists)
    }

    func testUploadSheetCancelDismissesSheet() {
        navigateToTestBucket()
        let uploadButton = app.buttons["Upload file"]
        XCTAssertTrue(uploadButton.waitForExistence(timeout: 5))
        uploadButton.tap()

        XCTAssertTrue(app.buttons["Photo Library"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Photo Library"].exists)
    }

    // MARK: - Staging screen

    func testStagingScreenShowsSelectedFiles() {
        launchWithAutoStage()
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.staticTexts["photo1.jpg"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["document.pdf"].exists)
    }

    func testStagingScreenShowsUploadButton() {
        launchWithAutoStage()
        navigateToTestBucket()
        openUploadSheet()

        // "Upload 2 Files" button should appear
        let uploadBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Upload'")).element(boundBy: 0)
        XCTAssertTrue(uploadBtn.waitForExistence(timeout: 3))
    }

    func testStagingCancelDismissesSheet() {
        launchWithAutoStage()
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.staticTexts["photo1.jpg"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
    }

    // MARK: - Success flow (auto-upload)

    func testUploadSuccessShowsCompletionBanner() {
        launchWithAutoUpload()
        navigateToTestBucket()
        openUploadSheet()

        let banner = app.staticTexts["1 file uploaded"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testUploadSuccessDoneButtonDismissesSheet() {
        launchWithAutoUpload()
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Done"].exists)
    }

    // MARK: - Failure flow (auto-upload + upload failure)

    func testUploadFailureShowsFailedSection() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login",
                               "--auto-upload", "--mock-upload-failure"]
        app.terminate()
        app.launch()

        navigateToTestBucket()
        openUploadSheet()

        // Summary shows "0 of 1 uploaded"
        let summary = app.staticTexts["0 of 1 uploaded"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].exists)
    }

    func testUploadFailureDoneButtonDismissesSheet() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login",
                               "--auto-upload", "--mock-upload-failure"]
        app.terminate()
        app.launch()

        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Done"].exists)
    }

    // MARK: - Helpers

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) {
            bucketCell.tap()
        }
    }

    private func openUploadSheet() {
        let uploadButton = app.buttons["Upload file"]
        if uploadButton.waitForExistence(timeout: 5) {
            uploadButton.tap()
        }
    }

    private func launchWithAutoUpload() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--auto-upload"]
        app.terminate()
        app.launch()
    }

    private func launchWithAutoStage() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login", "--auto-stage"]
        app.terminate()
        app.launch()
    }
}

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
        let lockIcon = app.images["Read only bucket"]
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

        // Sheet gone — breadcrumb should be visible again
        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Photo Library"].exists)
    }

    // MARK: - Success flow (auto-upload)

    func testUploadSuccessShowsBanner() {
        launchWithAutoUpload()
        navigateToTestBucket()
        openUploadSheet()

        let checkmark = app.staticTexts["Upload complete"]
        XCTAssertTrue(checkmark.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["View"].exists)
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

    func testUploadSuccessViewButtonOpensViewer() {
        launchWithAutoUpload()
        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["View"].waitForExistence(timeout: 5))
        app.buttons["View"].tap()

        // Viewer dismisses with Done
        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()
    }

    // MARK: - Failure flow (auto-upload + upload failure)

    func testUploadFailureShowsErrorMessage() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login",
                               "--auto-upload", "--mock-upload-failure"]
        app.terminate()
        app.launch()

        navigateToTestBucket()
        openUploadSheet()

        let errorTitle = app.staticTexts["Upload Failed"]
        XCTAssertTrue(errorTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Dismiss"].exists)
    }

    func testUploadFailureDismissButtonClosesSheet() {
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--skip-login",
                               "--auto-upload", "--mock-upload-failure"]
        app.terminate()
        app.launch()

        navigateToTestBucket()
        openUploadSheet()

        XCTAssertTrue(app.buttons["Dismiss"].waitForExistence(timeout: 5))
        app.buttons["Dismiss"].tap()

        XCTAssertTrue(app.staticTexts["test-bucket"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Upload Failed"].exists)
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
}

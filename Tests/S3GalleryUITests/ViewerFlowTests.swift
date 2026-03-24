import XCTest

final class ViewerFlowTests: XCTestCase {
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

    func testTapImageItemOpensPhotoViewer() {
        navigateToTestBucket()
        let imageItem = app.buttons.matching(NSPredicate(format: "label CONTAINS '.jpg'")).firstMatch
        guard imageItem.waitForExistence(timeout: 5) else { return }
        imageItem.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 5))
        doneButton.tap()

        // Should return to browser
        let breadcrumb = app.staticTexts["test-bucket"]
        XCTAssertTrue(breadcrumb.waitForExistence(timeout: 3))
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) {
            bucketCell.tap()
        }
    }
}

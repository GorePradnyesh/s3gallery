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

    func testSwipeNavigatesToAdjacentPhoto() {
        navigateToTestBucket()

        // Open sunset.jpg (second image alphabetically, index 1 in carousel)
        let sunsetItem = app.buttons.matching(NSPredicate(format: "label CONTAINS 'sunset.jpg'")).firstMatch
        XCTAssertTrue(sunsetItem.waitForExistence(timeout: 5), "sunset.jpg not found in bucket")
        sunsetItem.tap()

        // Viewer should open with sunset.jpg as title
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "Done button not visible")
        XCTAssertTrue(
            app.navigationBars["sunset.jpg"].waitForExistence(timeout: 3),
            "Navigation title should be sunset.jpg"
        )

        // Swipe right to go to the previous image (autumn.jpg, index 0)
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
        start.press(forDuration: 0.01, thenDragTo: end)

        // Title should update to autumn.jpg
        XCTAssertTrue(
            app.navigationBars["autumn.jpg"].waitForExistence(timeout: 3),
            "Navigation title should change to autumn.jpg after swipe"
        )

        // Done button should still be present
        XCTAssertTrue(app.buttons["Done"].exists, "Done button should still be visible")
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) {
            bucketCell.tap()
        }
    }
}

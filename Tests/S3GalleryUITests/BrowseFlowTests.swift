import XCTest

final class BrowseFlowTests: XCTestCase {
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

    func testBucketListDisplaysBuckets() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(bucketCell.waitForExistence(timeout: 5))
    }

    func testTapBucketEntersBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(bucketCell.waitForExistence(timeout: 5))
        bucketCell.tap()

        // Should show breadcrumb bar
        let breadcrumb = app.staticTexts["test-bucket"]
        XCTAssertTrue(breadcrumb.waitForExistence(timeout: 3))
    }

    func testSwitchBetweenListAndGridViews() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(bucketCell.waitForExistence(timeout: 5))
        bucketCell.tap()

        // Switch to list view
        let listViewButton = app.buttons["Switch to list view"]
        XCTAssertTrue(listViewButton.waitForExistence(timeout: 5))
        listViewButton.tap()
        XCTAssertTrue(app.buttons["Switch to grid view"].waitForExistence(timeout: 3))

        // Switch back to grid view
        app.buttons["Switch to grid view"].tap()
        XCTAssertTrue(app.buttons["Switch to list view"].waitForExistence(timeout: 3))
    }

    func testBreadcrumbNavigationPopsToParent() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(bucketCell.waitForExistence(timeout: 5))
        bucketCell.tap()

        // Enter a folder
        let folder = app.buttons.matching(NSPredicate(format: "label CONTAINS 'photos'")).firstMatch
        if folder.waitForExistence(timeout: 3) {
            folder.tap()
            // Tap the bucket breadcrumb to go back
            app.buttons["test-bucket"].tap()
            XCTAssertTrue(app.staticTexts["test-bucket"].exists)
        }
    }
}

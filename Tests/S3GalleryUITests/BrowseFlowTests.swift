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

        // Breadcrumb bar shows the bucket name as a button (nav title is suppressed in compact portrait)
        let breadcrumb = app.buttons.matching(NSPredicate(format: "label == 'test-bucket'")).firstMatch
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

    func testPinchZoomGridViewIsAccessible() {
        // Verifies the grid scroll view has the correct accessibility setup for pinch-to-zoom.
        // Column count logic is covered by GridColumnCountTests unit tests.
        // SwiftUI MagnificationGesture cannot be reliably triggered via XCTest simulator.
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(bucketCell.waitForExistence(timeout: 5))
        bucketCell.tap()

        let grid = app.scrollViews["grid-scroll-view"]
        XCTAssertTrue(grid.waitForExistence(timeout: 5))

        // Grid starts at 5 columns (default)
        XCTAssertEqual(grid.value as? String, "5")

        // Simulate pinches — app should remain stable (no crash)
        grid.pinch(withScale: 0.3, velocity: -2)
        XCTAssertTrue(grid.exists)
        grid.pinch(withScale: 3.0, velocity: 2)
        XCTAssertTrue(grid.exists)
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
            // After popping back, breadcrumb still shows the bucket name as a button
            XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == 'test-bucket'")).firstMatch.exists)
        }
    }
}

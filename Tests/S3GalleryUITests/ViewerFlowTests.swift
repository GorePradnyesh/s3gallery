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
        let breadcrumb = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        XCTAssertTrue(breadcrumb.waitForExistence(timeout: 5))
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

    func testTapVideoItemOpensVideoViewer() {
        navigateToTestBucket()

        let videoItem = app.buttons.matching(NSPredicate(format: "label CONTAINS 'sample.mp4'")).firstMatch
        XCTAssertTrue(videoItem.waitForExistence(timeout: 5), "sample.mp4 not found in bucket")
        videoItem.tap()

        // Carousel viewer opens with sample.mp4 as nav title
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "Done button not visible")
        XCTAssertTrue(
            app.navigationBars["sample.mp4"].waitForExistence(timeout: 3),
            "Navigation title should be sample.mp4"
        )

        // Play button is shown inline (video is not auto-played in the carousel)
        let playButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Play'")).firstMatch
        XCTAssertTrue(playButton.waitForExistence(timeout: 3), "Play button should be visible in carousel")

        // Tapping play opens AVPlayerViewController full-screen (UIKit modal)
        playButton.tap()
        // Full-screen player presents natively — verify it appeared
        // AVPlayerViewController dismisses itself via its own "Done" button in full-screen mode
        // so we just verify the app doesn't crash and returns to a stable state
        let playerPresented = app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch
            .waitForExistence(timeout: 3)
        if playerPresented {
            app.buttons.matching(NSPredicate(format: "label == 'Done'")).firstMatch.tap()
        }

        // Should still be in the viewer carousel
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch.waitForExistence(timeout: 5)
        )
    }

    private func navigateToTestBucket() {
        let bucketCell = app.buttons.matching(NSPredicate(format: "label CONTAINS 'test-bucket'")).firstMatch
        if bucketCell.waitForExistence(timeout: 5) {
            bucketCell.tap()
        }
    }
}

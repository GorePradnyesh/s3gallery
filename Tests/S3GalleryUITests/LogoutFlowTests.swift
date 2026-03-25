import XCTest

final class LogoutFlowTests: XCTestCase {
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

    func testLogoutNavigatesToLogin() {
        // Navigate to Settings
        let settingsButton = app.buttons["Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()

        // Tap Logout
        let logoutButton = app.buttons["Logout"]
        XCTAssertTrue(logoutButton.waitForExistence(timeout: 3))
        logoutButton.tap()

        // Confirm in the action sheet — wait for it to appear, then tap the destructive action
        let sheet = app.sheets.firstMatch
        let sheetLogout = sheet.buttons["Logout"]
        if sheetLogout.waitForExistence(timeout: 3) {
            sheetLogout.tap()
        } else {
            // Fallback: on some iOS versions confirmationDialog renders as an alert
            let alertLogout = app.alerts.firstMatch.buttons["Logout"]
            if alertLogout.waitForExistence(timeout: 2) { alertLogout.tap() }
        }

        // Should show login screen
        let connectButton = app.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
    }

    func testRelaunchWithoutCredentialsShowsLogin() {
        app.terminate()

        let freshApp = XCUIApplication()
        freshApp.launchArguments = ["--uitesting", "--no-keychain"]
        freshApp.launch()

        let connectButton = freshApp.buttons["Connect"]
        XCTAssertTrue(connectButton.waitForExistence(timeout: 5))
        freshApp.terminate()
    }
}

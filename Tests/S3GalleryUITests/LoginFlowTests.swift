import XCTest

final class LoginFlowTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--mock-s3-success", "--no-keychain"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    func testLoginWithValidCredentialsNavigatesToBrowser() throws {
        fillLoginForm(keyId: "AKIATESTKEY", secret: "testsecretkey", region: "us-east-1")
        app.buttons["Connect"].tap()

        let bucketList = app.navigationBars["S3 Gallery"]
        XCTAssertTrue(bucketList.waitForExistence(timeout: 5))
    }

    func testLoginWithInvalidCredentialsShowsError() throws {
        // Mock is configured to fail for "BADINVALID" key
        app.launchArguments = ["--uitesting", "--mock-s3-failure"]
        app.terminate()
        app.launch()

        fillLoginForm(keyId: "BADINVALIDKEY", secret: "badsecret", region: "us-east-1")
        app.buttons["Connect"].tap()

        let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Invalid'")).firstMatch
        XCTAssertTrue(errorText.waitForExistence(timeout: 5))
    }

    func testEmptyFieldsShowsValidationError() {
        app.buttons["Connect"].tap()
        let errorText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'required'")).firstMatch
        XCTAssertTrue(errorText.waitForExistence(timeout: 3))
    }

    private func fillLoginForm(keyId: String, secret: String, region: String) {
        let keyIdField = app.textFields["AKIAIOSFODNN7EXAMPLE"]
        keyIdField.tap()
        keyIdField.typeText(keyId)

        let secretField = app.secureTextFields.firstMatch
        secretField.tap()
        secretField.typeText(secret)

        let regionField = app.textFields["us-east-1"]
        regionField.tap()
        regionField.clearAndEnterText(region)
    }
}

private extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = value as? String else {
            typeText(text)
            return
        }
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        typeText(deleteString)
        typeText(text)
    }
}

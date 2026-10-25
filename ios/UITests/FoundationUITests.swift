import XCTest

final class FoundationUITests: XCTestCase {
    @MainActor func testSignedOutEntryAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["entryTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["entrySubtitle"].exists)
        XCTAssertFalse(app.buttons["signOutButton"].exists)
    }

    @MainActor func testOwnProfileAndSignOut() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-profile"]
        app.launch()
        XCTAssertTrue(app.staticTexts["profileTitle"].waitForExistence(timeout: 5))
        app.buttons["signOutButton"].tap()
        XCTAssertTrue(app.staticTexts["entryTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["profileTitle"].exists)
    }
}

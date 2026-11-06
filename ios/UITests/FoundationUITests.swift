import XCTest

final class FoundationUITests: XCTestCase {
    @MainActor func testA13RefusedConfigurationPrecedesFixtureAndLiveComposition() {
        for mode in ["-fixtures", "-live"] {
            let app = XCUIApplication()
            app.launchArguments = ["--ui-testing-refused", mode,
                "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            app.launch()
            XCTAssertTrue(app.staticTexts["backend-refused"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.textFields["Email"].exists)
            XCTAssertFalse(app.tabBars.firstMatch.exists)
            app.terminate()
        }
    }

    @MainActor func testSignedOutEntryAtAccessibilitySize() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.staticTexts["entryTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["entrySubtitle"].exists)
        XCTAssertFalse(app.buttons["signOutButton"].exists)
    }

    @MainActor func testLiveMainShowsHonestUnavailableAndSignsOut() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-phase", "main"]
        app.launch()
        XCTAssertTrue(app.staticTexts["liveUnavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        app.buttons["signOutButton"].tap()
        XCTAssertTrue(app.staticTexts["entryTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["liveUnavailable"].exists)
    }

    @MainActor func testLiveOnboardingGate() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-phase", "onboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["onboardingTitle"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["liveUnavailable"].exists)
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

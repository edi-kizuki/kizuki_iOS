// Related: [[012-b01-live-composition-seam]], [[2026-10-25-b01-report]].
import XCTest

/// Opt in locally with TEST_RUNNER_KIZUKI_LIVE_TESTS=1; CI has no local stack on macOS.
final class LocalLiveUITests: XCTestCase {
    @MainActor func testLiveModeReachesSignedOutEntry() throws {
        guard ProcessInfo.processInfo.environment["KIZUKI_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Opt-in local Supabase smoke test")
        }
        let app = XCUIApplication()
        app.launchArguments = ["-live", "-screen", "home"] // Live must ignore the fixture gallery router.
        app.launch()
        XCTAssertTrue(app.staticTexts["entryTitle"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["entrySubtitle"].exists)
        XCTAssertFalse(app.tabBars.firstMatch.exists)
        XCTAssertFalse(app.staticTexts["configurationTitle"].exists)
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "B01-local-live-signed-out-entry"
        shot.lifetime = .keepAlways
        add(shot)
    }
}

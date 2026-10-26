import XCTest

/// Opt in locally with TEST_RUNNER_KIZUKI_LIVE_TESTS=1; CI has no local stack on macOS.
final class LocalLiveUITests: XCTestCase {
    @MainActor func testLiveModeReachesSignedOutEntry() async throws {
        guard ProcessInfo.processInfo.environment["KIZUKI_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Opt-in local Supabase smoke test")
        }
        // A missing local stack is a failure, not a signed-out success from an empty Keychain.
        let key = try XCTUnwrap(ProcessInfo.processInfo.environment["KIZUKI_LOCAL_PUBLIC_KEY"])
        var request = URLRequest(url: URL(string: "http://127.0.0.1:54321/auth/v1/health")!)
        request.timeoutInterval = 5
        request.setValue(key, forHTTPHeaderField: "apikey")
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let app = XCUIApplication()
        app.launchArguments = ["-live", "-isolatedAuthStorage", "-screen", "home"] // Live must ignore the fixture gallery router.
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

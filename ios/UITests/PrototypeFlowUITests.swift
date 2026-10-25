import XCTest

/// Clicks through the fixture-backed prototype: entry, 12 onboarding steps, every tab, and
/// request → accept → Crew → chat. No backend is involved.
final class PrototypeFlowUITests: XCTestCase {
    @MainActor private func launch(_ args: [String] = ["-fixtures"]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    private func button(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    @MainActor func testEntryOnboardingAndEveryTab() {
        let app = launch()
        let apple = button(app, "Sign in with Apple")
        XCTAssertTrue(apple.waitForExistence(timeout: 8))
        apple.tap()
        // 18+ gate: Continue stays disabled until the box is ticked.
        XCTAssertFalse(button(app, "Continue").isEnabled)
        button(app, "I am 18 or older and agree to the Terms.").tap()
        button(app, "Continue").tap()
        // 12 onboarding steps; primers have a single Continue and nothing else.
        for step in 1...11 {
            let next = button(app, "Continue")
            XCTAssertTrue(next.waitForExistence(timeout: 3), "step \(step)")
            if step == 10 || step == 11 { XCTAssertEqual(app.buttons.matching(NSPredicate(format: "label ==[c] 'Continue'")).count, 1) }
            next.tap()
        }
        button(app, "Enter Kizuki").tap()

        XCTAssertTrue(app.staticTexts["Recommended projects"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["People that you might like"].exists)
        for tab in ["Search", "Suki", "My Projects", "Profile", "Home"] {
            let item = app.tabBars.buttons[tab]
            XCTAssertTrue(item.waitForExistence(timeout: 3), tab)
            item.tap()
            // Kizuki's own icons: the tapped tab reports itself as selected, the others do not.
            XCTAssertTrue(item.isSelected, "\(tab) selected")
            XCTAssertEqual(app.tabBars.buttons.matching(NSPredicate(format: "isSelected == true")).count, 1)
        }
        app.tabBars.buttons["My Projects"].tap()
        XCTAssertTrue(app.staticTexts["Drafts"].exists && app.staticTexts["Published"].exists && app.staticTexts["Past"].exists)
        app.tabBars.buttons["Suki"].tap()
        XCTAssertTrue(app.buttons["Crew"].exists && app.buttons["Requests"].exists && app.buttons["Create"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Matches'")).firstMatch.exists)
    }

    @MainActor func testRequestAcceptMovesPersonToCrewAndOpensChat() {
        let app = launch(["-fixtures", "-screen", "suki-requests"])
        XCTAssertTrue(app.staticTexts["Emil Sander"].waitForExistence(timeout: 8))
        button(app, "Accept").tap()
        // Accepting opens the chat with the new Crew member.
        XCTAssertTrue(app.textFields["Message Emil"].waitForExistence(timeout: 5))
        let field = app.textFields["Message Emil"]
        field.tap(); field.typeText("Hello from the test")
        button(app, "Send").tap()
        XCTAssertTrue(app.staticTexts["Hello from the test"].waitForExistence(timeout: 3))
        button(app, "Back").tap()
        app.buttons["Crew"].tap()
        XCTAssertTrue(app.staticTexts["Emil Sander"].waitForExistence(timeout: 3))
    }

    @MainActor func testChatIsLockedForPeopleOutsideCrew() {
        let app = launch(["-fixtures", "-screen", "chat-list"])
        XCTAssertTrue(app.staticTexts["Leni Falk"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Emil Sander"].exists)
    }

    @MainActor func testProfileOverflowOffersReportAndBlock() {
        let app = launch(["-fixtures", "-screen", "profile-other"])
        let more = button(app, "More")
        XCTAssertTrue(more.waitForExistence(timeout: 8))
        more.tap()
        XCTAssertTrue(button(app, "Report").waitForExistence(timeout: 3))
        XCTAssertTrue(button(app, "Block").exists)
        // Not in the Crew, so there is nothing to remove.
        XCTAssertFalse(button(app, "Remove from Crew").exists)
    }

    // MARK: Round 1 revisions

    @MainActor func testOtherProfileShowsAvailabilityAndWishToCollab() {
        let app = launch(["-fixtures", "-screen", "profile-other"])
        // Decision 51: availability is public. Decision 52: "Wish to Collab" from a profile, no project needed.
        XCTAssertTrue(button(app, "Wish to Collab").waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'is available to collab'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Ask to collaborate'")).firstMatch.exists)
        button(app, "Wish to Collab").tap()
        XCTAssertTrue(button(app, "Send request").waitForExistence(timeout: 5))
        button(app, "Send request").tap()
        XCTAssertTrue(app.staticTexts["Wish sent"].waitForExistence(timeout: 5))
    }

    @MainActor func testProjectOffersJoinProject() {
        let app = launch(["-fixtures", "-screen", "project-detail"])
        XCTAssertTrue(button(app, "Join project").waitForExistence(timeout: 8))
        XCTAssertFalse(button(app, "Ask to join").exists)
    }

    @MainActor func testRequestsListsNameTheRequestKind() {
        let app = launch(["-fixtures", "-screen", "suki-requests"])
        XCTAssertTrue(app.staticTexts["WISH TO COLLAB"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["JOIN PROJECT"].exists)
    }

    @MainActor func testRemoveFromCrewAsksFirstAndClosesTheChat() {
        let app = launch(["-fixtures", "-screen", "suki-crew"])
        let name = "Aya Morita"
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 8))
        // Cancel keeps the person in the Crew.
        button(app, "More options for \(name)").tap()
        button(app, "Remove from Crew").tap()
        XCTAssertTrue(app.staticTexts["Remove Aya from your Crew?"].waitForExistence(timeout: 3))
        // iOS 26 shows this as a small floating sheet with no Cancel button: tapping outside dismisses it.
        let cancel = button(app, "Cancel")
        if cancel.exists { cancel.tap() } else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.08)).tap() }
        XCTAssertTrue(app.staticTexts["Remove Aya from your Crew?"].waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[name].exists)
        // Confirm removes them. They are not blocked, so Block is a separate action.
        button(app, "More options for \(name)").tap()
        button(app, "Remove from Crew").tap()
        XCTAssertTrue(app.staticTexts["Remove Aya from your Crew?"].waitForExistence(timeout: 3))
        button(app, "Remove from Crew").tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.staticTexts[name])
        waitForExpectations(timeout: 5)
    }

    @MainActor func testSearchShowsPhotosAndShortVideosOnly() {
        let app = launch(["-fixtures", "-screen", "search"])
        XCTAssertTrue(app.textFields["Search photos & videos"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Short video'")).firstMatch.exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Collab photo'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["People"].exists)
    }

    @MainActor func testGetDiscoveredCardOpensEditProfile() {
        let app = launch(["-fixtures", "-screen", "profile"])
        XCTAssertTrue(app.staticTexts["Get discovered"].waitForExistence(timeout: 8))
        button(app, "Write a short bio").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
    }
}

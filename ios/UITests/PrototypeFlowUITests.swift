import XCTest

/// Clicks through the fixture-backed prototype: entry, onboarding, every tab, and
/// request → accept → Crew → chat. No backend is involved.
final class PrototypeFlowUITests: XCTestCase {
    @MainActor private func revealFeedBanner(_ banner: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<30 {
            let frame = banner.frame
            let bottom = app.tabBars.firstMatch.frame.minY
            if frame.height > 0 && frame.minY > 130 && frame.maxY < bottom && banner.isHittable { return }
            app.scrollViews["feed-scroll"].swipeUp(velocity: .slow)
        }
        XCTFail("Feed banner not reachable")
    }

    @MainActor func testFeedPromptsOpenDraftRequestsAndProfileEditor() {
        let app = launch(["-fixtures", "-screen", "home"])
        let draft = app.buttons["feed-prompt-draft"]
        XCTAssertTrue(draft.waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts["Your next move"].exists)
        XCTAssertGreaterThanOrEqual(draft.frame.height, 44)
        XCTAssertLessThanOrEqual(draft.frame.height, 48)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Floating-feed-prompts"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        draft.tap()
        XCTAssertTrue(app.navigationBars["Your project"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        let requests = app.buttons["feed-prompt-requests"]
        revealFeedBanner(requests, in: app)
        XCTAssertTrue(requests.isHittable)
        requests.tap()
        XCTAssertTrue(app.tabBars.buttons["Suki"].isSelected)
        XCTAssertTrue(app.segmentedControls.buttons["Requests"].isSelected)
        XCTAssertTrue(app.segmentedControls.buttons["Incoming"].isSelected)
        app.tabBars.buttons["Home"].tap()
        let profile = app.buttons["feed-prompt-profile"]
        revealFeedBanner(profile, in: app)
        XCTAssertTrue(profile.isHittable)
        profile.tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
    }

    @MainActor func testFeedPromptsStackAtAccessibilitySize() {
        let app = launch(["-fixtures", "-screen", "home", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXL"])
        let draft = app.buttons["feed-prompt-draft"]
        let requests = app.buttons["feed-prompt-requests"]
        XCTAssertTrue(draft.waitForExistence(timeout: 8))
        XCTAssertFalse(app.scrollViews["feed-prompts"].exists)
        XCTAssertFalse(app.staticTexts["Your next move"].exists)
        XCTAssertGreaterThanOrEqual(draft.frame.minX, 10)
        XCTAssertLessThanOrEqual(draft.frame.maxX, app.frame.maxX - 10)
        revealFeedBanner(requests, in: app)
        XCTAssertTrue(requests.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Floating-feed-prompts-accessibility"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        requests.tap()
        XCTAssertTrue(app.segmentedControls.buttons["Incoming"].isSelected)
    }

    @MainActor func testFloatingCardsAtDefaultAndAccessibilitySizes() {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXL"] {
            for screen in ["suki-requests", "suki-create", "my-projects"] {
                let app = launch(["-fixtures", "-screen", screen, "-UIPreferredContentSizeCategoryName", size])
                let action: XCUIElement
                switch screen {
                case "suki-requests": action = app.buttons["Accept"].firstMatch
                case "suki-create": action = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Create a project")).firstMatch
                default: action = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Blue hour")).firstMatch
                }
                XCTAssertTrue(action.waitForExistence(timeout: 8))
                XCTAssertTrue(action.isHittable)
                XCTAssertGreaterThanOrEqual(action.frame.minX, 10)
                XCTAssertLessThanOrEqual(action.frame.maxX, app.frame.maxX - 10)
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Floating-\(screen)-\(size)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
                app.terminate()
            }
        }
    }

    @MainActor func testOptionalWidgetsRetainLinksWhenTurnedOff() {
        let app = launch(["-fixtures", "-screen", "profile-edit"])
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 8))
        func reveal(_ element: XCUIElement) {
            for _ in 0..<35 {
                let top = app.navigationBars["Edit profile"].frame.maxY + 12
                let bottom = button(app, "Save").frame.minY - 20
                if element.isHittable && element.frame.minY > top && element.frame.maxY < bottom { return }
                let reverse = element.exists && element.frame.height > 0 && element.frame.minY < top
                let upper = top + (bottom - top) * 0.25
                let lower = top + (bottom - top) * 0.75
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: app.frame.midX, dy: reverse ? upper : lower))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: reverse ? lower : upper)))
            }
            XCTFail("Widget control not reachable")
        }
        let widgets = [("SoundCloud", "https://soundcloud.com/artist/track"), ("Bandcamp", "https://artist.bandcamp.com/album/example"), ("TikTok", "https://www.tiktok.com/@artist")]
        for (provider, url) in widgets {
            let connect = button(app, "Connect \(provider)")
            reveal(connect)
            connect.tap()
            let field = app.textFields[provider]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(String(url.dropFirst("https://".count)))
            button(app, "Use link").tap()
            XCTAssertTrue(app.navigationBars[provider].waitForNonExistence(timeout: 5))
            XCTAssertTrue(button(app, "Save").isEnabled)
        }
        button(app, "Save").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForNonExistence(timeout: 5))
        button(app, "Edit profile").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
        for (provider, url) in widgets {
            let toggle = app.switches["Show \(provider) on profile"]
            reveal(toggle)
            XCTAssertEqual(toggle.value as? String, "1")
            toggle.tap()
            let edit = button(app, "Edit \(provider)")
            reveal(edit)
            edit.tap()
            XCTAssertTrue(app.textFields[provider].waitForExistence(timeout: 5))
            XCTAssertEqual(app.textFields[provider].value as? String, url)
            button(app, "Cancel").tap()
            XCTAssertTrue(app.navigationBars[provider].waitForNonExistence(timeout: 5))
        }
        button(app, "Save").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForNonExistence(timeout: 5))
        button(app, "Edit profile").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
        for (provider, url) in widgets {
            let toggle = app.switches["Show \(provider) on profile"]
            reveal(toggle)
            XCTAssertEqual(toggle.value as? String, "0")
            let edit = button(app, "Edit \(provider)")
            reveal(edit)
            edit.tap()
            XCTAssertTrue(app.textFields[provider].waitForExistence(timeout: 5))
            XCTAssertEqual(app.textFields[provider].value as? String, url)
            button(app, "Cancel").tap()
            XCTAssertTrue(app.navigationBars[provider].waitForNonExistence(timeout: 5))
        }
    }

    @MainActor func testInvalidWidgetDraftCanBeCancelledWithoutBlockingProfileSave() {
        let app = launch(["-fixtures", "-screen", "profile-edit"])
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 8))
        let connect = button(app, "Connect SoundCloud")
        for _ in 0..<30 {
            let top = app.navigationBars["Edit profile"].frame.maxY + 12
            let bottom = button(app, "Save").frame.minY - 20
            if connect.isHittable && connect.frame.minY > top && connect.frame.maxY < bottom { break }
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: app.frame.midX, dy: top + (bottom - top) * 0.75))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: top + (bottom - top) * 0.25)))
        }
        connect.tap()
        XCTAssertTrue(app.textFields["SoundCloud"].waitForExistence(timeout: 5))
        app.textFields["SoundCloud"].tap()
        app.textFields["SoundCloud"].typeText("https://soundcloud.com.evil.test/artist")
        button(app, "Use link").tap()
        XCTAssertTrue(app.staticTexts["widget-url-error"].waitForExistence(timeout: 3))
        button(app, "Cancel").tap()
        XCTAssertTrue(app.navigationBars["SoundCloud"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(button(app, "Save").isEnabled)
        button(app, "Save").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForNonExistence(timeout: 5))
    }
    @MainActor private func launch(_ args: [String] = ["-fixtures"]) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        return app
    }

    @MainActor private func button(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", label)).firstMatch
    }

    @MainActor func testPainterIsSelectableInVisualArtsOnboarding() {
        let app = launch(["-fixtures", "-screen", "onb-realm"])
        button(app, "Visual arts").tap()
        button(app, "Continue").tap()
        let painter = button(app, "Painter")
        XCTAssertTrue(painter.waitForExistence(timeout: 5))
        XCTAssertEqual(painter.value as? String, "Main")
        button(app, "Illustrator").tap()
        XCTAssertEqual(button(app, "Illustrator").value as? String, "Secondary")
    }

    @MainActor func testInspirationPathSkipsRolesAndLandsInDiscovery() {
        let app = launch(["-fixtures", "-screen", "onb-goal"])
        button(app, "Explore and get inspired").tap()
        button(app, "Continue").tap()
        XCTAssertTrue(app.staticTexts["WHAT WORLDS INSPIRE YOU?"].exists)
        button(app, "Visual arts").tap()
        button(app, "Continue").tap()
        XCTAssertTrue(app.staticTexts["WHAT CATCHES YOUR EYE?"].exists)
        button(app, "Continue").tap()
        XCTAssertFalse(app.staticTexts["YOUR FAVOURITES, YOUR WORLD"].exists)
        XCTAssertTrue(app.staticTexts["WHERE DO YOU CREATE?"].exists)
        XCTAssertFalse(app.staticTexts["How do you want to work?"].exists)
        button(app, "Continue").tap()
        button(app, "Continue").tap()
        button(app, "Start exploring").tap()
        XCTAssertTrue(app.tabBars.buttons["Search"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Search"].isSelected)
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Here for inspiration"].exists)
        XCTAssertFalse(app.staticTexts["I’m available to collab"].exists)
    }

    @MainActor func testFeedOwnsInboxAndProfileOwnsSettings() {
        let app = launch(["-fixtures", "-screen", "home"])
        XCTAssertTrue(button(app, "Messages").waitForExistence(timeout: 8))
        XCTAssertFalse(button(app, "Settings").exists)
        button(app, "Messages").tap()
        XCTAssertTrue(app.navigationBars["Messages"].waitForExistence(timeout: 5))
        app.navigationBars["Messages"].buttons.firstMatch.tap()
        for label in ["Search", "Suki", "My Projects"] {
            app.tabBars.buttons[label].tap()
            XCTAssertTrue(app.tabBars.buttons[label].isSelected)
            XCTAssertFalse(app.descendants(matching: .any)["tab-header-minimal"].exists)
            XCTAssertFalse(app.descendants(matching: .any)["tab-header-symbol"].exists)
            XCTAssertFalse(button(app, "Settings").exists)
            XCTAssertFalse(button(app, "Messages").exists)
            if label == "Search" { XCTAssertLessThan(app.textFields["Search photos & videos"].frame.minY, 120) }
        }
        app.tabBars.buttons["Profile"].tap()
        XCTAssertFalse(button(app, "Messages").exists)
        let settings = button(app, "Settings")
        XCTAssertTrue(settings.isHittable)
        XCTAssertGreaterThan(settings.frame.maxX, app.frame.maxX - 40)
        XCTAssertLessThan(settings.frame.minY, 130)
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls.buttons["Symbols"].exists)
        app.navigationBars["Settings"].buttons.firstMatch.tap()
        XCTAssertTrue(app.tabBars.buttons["Profile"].isSelected)
        button(app, "Edit profile").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
    }

    @MainActor func testProfileMenuAtLargestTextSize() {
        let app = launch(["-fixtures", "-screen", "profile", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        let settings = button(app, "Settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 8))
        XCTAssertTrue(settings.isHittable)
        XCTAssertGreaterThanOrEqual(settings.frame.width, 44)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44)
        XCTAssertFalse(button(app, "Messages").exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Flush-profile-accessibility"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor func testProfileCoverReachesScreenEdges() {
        let app = launch(["-fixtures", "-screen", "profile"])
        let scroll = app.scrollViews["profile-scroll"]
        XCTAssertTrue(scroll.waitForExistence(timeout: 8))
        XCTAssertEqual(scroll.frame.minX, app.frame.minX, accuracy: 1)
        XCTAssertEqual(scroll.frame.maxX, app.frame.maxX, accuracy: 1)
        XCTAssertEqual(scroll.frame.minY, app.frame.minY, accuracy: 1)
        let identity = app.otherElements["profile-identity"]
        XCTAssertTrue(identity.exists)
        XCTAssertEqual(identity.frame.minY, 160, accuracy: 2)
        let settings = button(app, "Settings")
        XCTAssertTrue(settings.isHittable)
        XCTAssertGreaterThan(settings.frame.minY, scroll.frame.minY)
        XCTAssertLessThanOrEqual(settings.frame.maxY, identity.frame.minY)
        XCTAssertGreaterThanOrEqual(settings.frame.width, 44)
        XCTAssertGreaterThanOrEqual(settings.frame.height, 44)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Flush-profile"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        button(app, "Edit profile").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
    }

    @MainActor func testDebugDefaultAndTabBarAccessibilityScreenshots() {
        let app = launch(["-screen", "home"]) // No -fixtures: Debug still defaults to fixtures.
        XCTAssertTrue(app.staticTexts["Recommended projects"].waitForExistence(timeout: 8))
        for label in ["Home", "Search", "Suki", "My Projects", "Profile"] {
            let tab = app.tabBars.buttons[label]
            XCTAssertTrue(tab.exists, "VoiceOver label: \(label)")
            XCTAssertEqual(tab.label, label)
            tab.tap()
            XCTAssertTrue(tab.isSelected)
            XCTAssertEqual(app.tabBars.buttons.matching(NSPredicate(format: "isSelected == true")).count, 1)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "B01-tab-\(label)-iOS-\(ProcessInfo.processInfo.operatingSystemVersionString)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
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
        // The final location primer enters the app without an extra confirmation screen.
        for step in 1...10 {
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
        button(app, "Back").tap()
        app.tabBars.buttons["Home"].tap()
        let greeting = app.buttons["feed-prompt-crew"]
        XCTAssertTrue(greeting.waitForExistence(timeout: 5))
        revealFeedBanner(greeting, in: app)
        XCTAssertTrue(greeting.isHittable)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Feed-new-Crew-prompt"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        greeting.tap()
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

    @MainActor func testProfileAvailabilityBatteryAndFloatingWidgetsAtNormalAndLargestText() {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launch(["-fixtures", "-screen", "profile-other", "-UIPreferredContentSizeCategoryName", size])
            let availability = app.descendants(matching: .any)["profile-availability"]
            XCTAssertTrue(availability.waitForExistence(timeout: 8))
            XCTAssertTrue(availability.label.contains("Sami is available to collab"), availability.label)
            XCTAssertTrue(availability.label.contains("Low availability"), availability.label)
            XCTAssertTrue(availability.label.contains("Under 5 hours / week"), availability.label)
            XCTAssertFalse(availability.label.contains("Only you see"), availability.label)
            XCTAssertGreaterThanOrEqual(availability.frame.minX, 10)
            XCTAssertLessThanOrEqual(availability.frame.maxX, app.frame.maxX - 10)
            XCTAssertFalse(app.staticTexts["Favourites"].exists)
            let work = app.descendants(matching: .any)["profile-work-SoundCloud"]
            let scroll = app.scrollViews["profile-scroll"]
            for _ in 0..<12 where !(work.exists && work.isHittable && work.frame.maxY < app.frame.maxY - 60) {
                scroll.swipeUp()
            }
            XCTAssertTrue(work.exists)
            XCTAssertGreaterThanOrEqual(work.frame.minX, 10)
            XCTAssertLessThanOrEqual(work.frame.maxX, app.frame.maxX - 10)
            XCTAssertTrue(app.staticTexts["Demo link · not connected"].firstMatch.exists)
            XCTAssertFalse(app.staticTexts["Favourites"].exists)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Profile-availability-widgets-\(size)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            app.terminate()
        }
    }

    @MainActor func testOwnProfileBatteryFollowsSavedAvailabilityAndLinkActionFloats() {
        let app = launch(["-fixtures", "-screen", "profile"])
        let availability = app.descendants(matching: .any)["profile-availability"]
        XCTAssertTrue(availability.waitForExistence(timeout: 8))
        XCTAssertTrue(availability.label.contains("I’m available to collab"), availability.label)
        XCTAssertTrue(availability.label.contains("Medium availability"), availability.label)
        XCTAssertTrue(availability.label.contains("5–9 hours / week"), availability.label)
        XCTAssertTrue(availability.label.contains("Only you see work mode and pay preference"), availability.label)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '5–10 hours'")).firstMatch.exists)
        button(app, "Edit profile").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
        func reveal(_ element: XCUIElement) {
            for _ in 0..<35 {
                let top = app.navigationBars["Edit profile"].frame.maxY + 12
                let bottom = button(app, "Save").frame.minY - 20
                if element.isHittable && element.frame.minY > top && element.frame.maxY < bottom { return }
                let reverse = element.exists && element.frame.height > 0 && element.frame.minY < top
                let upper = top + (bottom - top) * 0.25
                let lower = top + (bottom - top) * 0.75
                let origin = app.coordinate(withNormalizedOffset: .zero)
                origin.withOffset(CGVector(dx: app.frame.midX, dy: reverse ? upper : lower))
                    .press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: app.frame.midX, dy: reverse ? lower : upper)))
            }
            XCTFail("Edit control not reachable: \(element.debugDescription)")
        }
        let high = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "10+ hours / week")).firstMatch
        reveal(high)
        high.tap()
        XCTAssertTrue(high.isSelected)
        let connect = button(app, "Connect SoundCloud")
        reveal(connect)
        connect.tap()
        let field = app.textFields["SoundCloud"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("soundcloud.com/artist/track")
        button(app, "Use link").tap()
        XCTAssertTrue(app.navigationBars["SoundCloud"].waitForNonExistence(timeout: 5))
        button(app, "Save").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(availability.waitForExistence(timeout: 5))
        XCTAssertTrue(availability.label.contains("High availability"), availability.label)
        XCTAssertTrue(availability.label.contains("10+ hours / week"), availability.label)
        let work = app.descendants(matching: .any)["profile-work-SoundCloud"]
        let scroll = app.scrollViews["profile-scroll"]
        for _ in 0..<12 where !(work.exists && work.isHittable && work.frame.maxY < app.frame.maxY - 60) {
            scroll.swipeUp()
        }
        XCTAssertTrue(work.exists)
        XCTAssertGreaterThanOrEqual(work.frame.minX, 10)
        XCTAssertLessThanOrEqual(work.frame.maxX, app.frame.maxX - 10)
        let open = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Open on SoundCloud'")).firstMatch
        XCTAssertTrue(open.exists)
        XCTAssertTrue(open.isHittable)
        XCTAssertGreaterThanOrEqual(open.frame.height, 44)
        XCTAssertGreaterThanOrEqual(open.frame.minX, work.frame.minX)
        XCTAssertLessThanOrEqual(open.frame.maxX, work.frame.maxX)
        XCTAssertTrue(app.staticTexts["SoundCloud · opens externally"].exists)
        XCTAssertFalse(app.staticTexts["Favourites"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Profile-own-high-availability-link"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor func testFavouritesSurfacesAreGone() {
        var app = launch(["-fixtures", "-screen", "settings-privacy"])
        XCTAssertTrue(app.switches["Use taste for recommendations"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.switches["Use favourites for recommendations"].exists)
        XCTAssertFalse(app.switches["Show favourites on my profile"].exists)
        app.terminate()
        app = launch(["-fixtures", "-screen", "onb-taste"])
        XCTAssertTrue(app.staticTexts["WHAT CATCHES YOUR EYE?"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["5 / 10"].exists)
        button(app, "Continue").tap()
        XCTAssertFalse(app.staticTexts["YOUR FAVOURITES, YOUR WORLD"].exists)
        XCTAssertFalse(app.textFields["Search films and music"].exists)
        XCTAssertTrue(app.staticTexts["WHAT KIND OF WORK?"].exists)
        XCTAssertTrue(app.staticTexts["6 / 10"].exists)
        button(app, "Continue").tap()
        XCTAssertTrue(app.staticTexts["HOW MUCH TIME DO YOU HAVE?"].exists)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "5–9 hours / week")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '5–10 hours'")).firstMatch.exists)
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

    @MainActor func testCrewActionsAlignAndOpenChatAtDefaultAndAccessibilityXL() {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXL"] {
            let app = launch(["-fixtures", "-screen", "suki-crew", "-UIPreferredContentSizeCategoryName", size])
            let message = button(app, "Message Aya Morita")
            let more = button(app, "More options for Aya Morita")
            let profile = button(app, "View profile for Aya Morita")
            XCTAssertTrue(message.waitForExistence(timeout: 8))
            XCTAssertTrue(more.isHittable)
            XCTAssertTrue(profile.isHittable)
            for action in [message, more] {
                XCTAssertEqual(action.frame.width, 44, accuracy: 1, action.label)
                XCTAssertEqual(action.frame.height, 44, accuracy: 1, action.label)
            }
            XCTAssertLessThanOrEqual(profile.frame.maxX, message.frame.minX)
            XCTAssertEqual(message.frame.midY, more.frame.midY, accuracy: 1)
            XCTAssertEqual(profile.frame.midY, more.frame.midY, accuracy: 1)
            XCTAssertEqual(more.frame.minX - message.frame.maxX, 8, accuracy: 1)
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "Crew-actions-\(size)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            message.tap()
            XCTAssertTrue(app.textFields["Message Aya"].waitForExistence(timeout: 5))
            app.terminate()
        }
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
        button(app, "Write a short bio (10+ characters)").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
    }

    @MainActor func testFourOnboardingRolesAndMainPromotion() {
        let app = launch(["-fixtures", "-screen", "onb-roles"])
        XCTAssertTrue(button(app, "Producer").waitForExistence(timeout: 8))
        for role in ["Cinematographer", "Producer"] { button(app, role).tap() }
        button(app, "Editor").tap()
        XCTAssertFalse(button(app, "Make Editor main").exists)
        button(app, "Make Producer main").tap()
        XCTAssertFalse(button(app, "Make Producer main").exists)
        XCTAssertTrue(button(app, "Make Director main").exists)
        button(app, "Producer").tap()
        XCTAssertFalse(button(app, "Make Director main").exists)
        button(app, "Editor").tap()
        XCTAssertTrue(button(app, "Make Editor main").exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "four-onboarding-roles"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor func testEditorFourRolesAndMainAtNormalAndLargeText() {
        for size in ["UICTContentSizeCategoryL", "UICTContentSizeCategoryAccessibilityXXXL"] {
            let app = launch(["-fixtures", "-screen", "profile-edit", "-UIPreferredContentSizeCategoryName", size])
            XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 8))
            let scroll = app.scrollViews.firstMatch
            func scrollStep(down: Bool) {
                let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.65 : 0.35))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.65))
                start.press(forDuration: 0.05, thenDragTo: end)
            }
            func reveal(_ element: XCUIElement) {
                for _ in 0..<20 {
                    if element.isHittable && element.frame.minY > app.navigationBars["Edit profile"].frame.maxY + 8 && element.frame.maxY < button(app, "Save").frame.minY - 16 { return }
                    scrollStep(down: true)
                }
                XCTAssertTrue(element.isHittable)
            }
            for role in ["Cinematographer", "Producer"] {
                let choice = button(app, role)
                reveal(choice)
                choice.tap()
            }
            let promote = button(app, "Make Producer main")
            reveal(promote)
            promote.tap()
            let producer = button(app, "Producer")
            for _ in 0..<20 {
                if producer.isHittable { break }
                scrollStep(down: false)
            }
            XCTAssertEqual(producer.value as? String, "Main")
            let screenshot = XCTAttachment(screenshot: app.screenshot())
            screenshot.name = "four-editor-roles-\(size)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            button(app, "Save").tap()
            XCTAssertTrue(app.navigationBars["Edit profile"].waitForNonExistence(timeout: 5))
            button(app, "Edit profile").tap()
            XCTAssertTrue(app.navigationBars["Edit profile"].waitForExistence(timeout: 5))
            reveal(producer)
            XCTAssertEqual(producer.value as? String, "Main")
            app.terminate()
        }
    }

    @MainActor func testSavingProfileBasicsHidesChecklistImmediately() {
        let app = launch(["-fixtures", "-screen", "profile"])
        XCTAssertTrue(app.staticTexts["Get discovered"].waitForExistence(timeout: 8))
        button(app, "Write a short bio (10+ characters)").tap()
        let bio = app.descendants(matching: .any).matching(NSPredicate(format: "label == 'Bio' AND (elementType == %d OR elementType == %d)", XCUIElement.ElementType.textField.rawValue, XCUIElement.ElementType.textView.rawValue)).firstMatch
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        bio.tap()
        bio.typeText("Making films with friends.")
        XCTAssertTrue(button(app, "Save").isHittable)
        button(app, "Save").tap()
        XCTAssertTrue(app.navigationBars["Edit profile"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Get discovered"].exists)
        app.tabBars.buttons["Home"].tap()
        app.tabBars.buttons["Profile"].tap()
        XCTAssertFalse(app.staticTexts["Get discovered"].exists)
        button(app, "Edit profile").tap()
        XCTAssertTrue(bio.waitForExistence(timeout: 5))
        XCTAssertTrue((bio.value as? String)?.contains("Making films with friends.") == true)
    }
}

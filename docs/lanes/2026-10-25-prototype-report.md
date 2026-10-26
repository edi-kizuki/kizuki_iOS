---
title: Kizuki hero-screen prototype, round 1
created: 2026-10-25
tags: [project/kizuki, prototype, architecture-round-1]
status: built-and-verified
---

# Kizuki hero-screen prototype, round 1

Related: [[2026-10-25-architecture-concept-v2]], [[2026-10-24-architecture-round-1-interview]], [[2026-10-25-design-tokens]], [[playbook]]

The prototype lives inside the real app (playbook section 7: grow the real app from the prototype). It is a set of feature modules in `ios/Packages/KizukiKit`, reading fixture data through Core repository protocols. No networking, no Supabase calls from any new screen. The old standalone `prototype/` folder is deleted; its tokens, fonts, fixtures and screens were moved into the modules below.

## Run it

```sh
./scripts/generate-project.sh          # XcodeGen, root project.yml
# Xcode: scheme Kizuki-Local, iPhone 17 Pro. Or from the shell:
xcodebuild -project ios/Kizuki.xcodeproj -scheme Kizuki-Local -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath .build/DerivedData \
  -onlyUsePackageVersionsFromResolvedFile CODE_SIGNING_ALLOWED=NO build
xcrun simctl install booted .build/DerivedData/Build/Products/Debug-iphonesimulator/Kizuki.app
xcrun simctl launch booted club.kizuki.ios.local -fixtures
```

- A Debug launch shows the fixture prototype by default. Pass `-live` to get the original foundation root (Supabase session) instead. `-fixtures` forces the prototype.
- `--ui-testing` still routes to the foundation root, so the old UI tests are untouched.
- Open any screen directly: `xcrun simctl launch booted club.kizuki.ios.local -screen home -fixtures`.
- Do not use the iPhone 16e (the user is viewing an app there). The gallery script refuses its UDID.

### Screenshot gallery

```sh
scripts/screenshot-gallery.sh                 # build, then all 40 screens (39 at round 1) -> hub/prototypes/2026-10-25-<id>.png
scripts/screenshot-gallery.sh --no-build home chat suki-requests   # a few screens, no rebuild
```

Screen ids: `splash login eligibility onb-handle onb-goal onb-realm onb-roles onb-taste onb-favourites onb-compensation onb-availability onb-city onb-primer-notifications onb-primer-location onb-ready home project-detail request-form search search-post suki-crew suki-requests suki-sent request-detail suki-create create-project post-collab my-projects my-project-owner profile profile-other profile-edit report chat-list chat settings settings-account settings-privacy settings-delete`. A unit test checks the script lists the ids.

Screenshots are in `hub/prototypes/` (39 PNGs, 1206 x 2622, status bar fixed at 9:41).

## Module layout

All new targets sit in the one `KizukiKit` package; the App target composes them.

| Target | Contents |
| --- | --- |
| `KizukiCore` (extended) | Domain models (`Person`, `Project`, `CollabRequest`, `Conversation`, `CollabPhoto`, `OwnProfile`, `Recommendation`), six repository protocols plus a `Dependencies` struct, `AppRoute` / `AppSheet` / `AppTab`, `@Observable AppRouter` (one path per tab), `@Observable AppStore` (loads through the protocols, refreshes after each mutation). Existing session and config code untouched. |
| `KizukiDesignSystem` (extended) | Full token palette, Londrina Solid / DM Sans / DM Mono (bundled, registered at runtime, OFL licences alongside), primary button with hard offset shadow, chips, reason chips, rough-edge shapes, placeholder artwork, Blobatar avatar wrapper, fields, top bar, flow layout. |
| `KizukiTestSupport` (new) | `FixtureData` (20 Berlin-first creators, 10 projects, 12 requests covering every state both ways, 3 chats, 30 collab photos) and `FixtureBackend` (an actor implementing every repository protocol, in memory). Every file is wrapped in `#if DEBUG`, so Release products are empty. |
| `KizukiOnboardingFeature` | Splash, sign-in stubs, 18+ and Terms, 12 onboarding steps including both primers. |
| `KizukiHomeFeature` | Home feed, project detail (visitor), request composer. |
| `KizukiSearchFeature` | Search grid, chips, query, post viewer. |
| `KizukiSukiFeature` | Crew, Requests (incoming and sent), request detail, create chooser, create-project form, post-a-collab form. |
| `KizukiMyProjectsFeature` | Drafts / Published / Past, owner project view (publish, close, mark done, invite, members). |
| `KizukiProfileFeature` | Own and other profile, embed cards, link rows, collab grid, edit profile. |
| `KizukiChatFeature` | Conversation list, chat thread. |
| `KizukiSettingsFeature` | Settings root and pages, blocked list, delete-account confirmation, report sheet. |
| App target (`ios/App`) | `KizukiApp.swift` (Debug default launches the prototype), `PrototypeRoot.swift` (system `TabView`, one `NavigationStack` per tab, route and sheet resolution, `GalleryScreen` launch router). |

Features depend only on Core and DesignSystem. They never import Infrastructure or each other; cross-feature navigation goes through `AppRoute` in Core. The live Supabase repositories will implement the same protocols and replace `FixtureBackend.dependencies()` at the composition root.

## Screens built

- **Entry:** splash, Sign in with Apple and Continue with email (both stubs, no network), one combined 18+ and Terms checkbox with a Terms sheet.
- **Onboarding (12 steps):** handle and name, goal (plus Start/Join follow-up), realm, roles (up to 3), taste cards (placeholder gradients), favourites picker (films and music, search, two consent toggles), compensation label, availability, city and work mode, notification primer, location primer, ready. Primers have one Continue button and nothing else.
- **Home:** Finish-your-project card (start-intent users), Recommended projects carousel with match-reason chips, People that you might like grid with a reason chip, gear and DM icons.
- **Search:** cream search field, chips, 3-column gap-free grid of gradient placeholders, post viewer (caption, author, like, save, Report; no comments).
- **Suki:** segmented Crew / Requests / Create. Crew lists accepted connections. Requests has Incoming and Sent with Accept, Decline, Withdraw and every state. Create offers "Create a project" and "Post a collab". Request form is role, time investment, note; no payment.
- **My Projects:** Drafts, Published (owned plus joined, labelled "Joined"), Past. Owner view with publish, close, mark done, invite (demo), seats and members.
- **Profile:** Blobatar avatar, roles, bio, own-only availability card, favourites, YouTube / SoundCloud / Bandcamp embed cards (mock player), Instagram and Letterboxd link rows, collab grid. Other people: "Ask to collaborate" and an overflow menu with Report and Block.
- **Chat:** list and thread. Reachable only for Crew. Accepting a request moves the person into Crew and opens the chat.
- **Settings:** account, notifications, privacy and safety (matching toggles, blocked list with Unblock), help, legal, Delete account (confirmation only).
- No follows, comments, ratings or payments anywhere. The word "Matches" does not appear.

## Verification

- Build: Kizuki-Local, Debug, iPhone 17 Pro simulator, clean. A Staging build stops at the existing "Validate release configuration" script (no real staging URL or key is configured), so the Release-side compile of the `#if DEBUG` guards was not run. All prototype code in the App target is inside `#if DEBUG`.
- Unit tests (27): the 21 foundation tests plus 6 new in `ios/Tests/PrototypeStoreTests.swift` (fixture counts and all request states, accept moves into Crew and creates a chat, decline does not, block hides and removes from Crew, duplicate requests ignored, gallery script lists the ids). All pass.
- UI tests: the 2 foundation tests plus 4 new in `ios/UITests/PrototypeFlowUITests.swift`. They click splash, Apple stub, 18+ gate, all 12 onboarding steps (primers have a single Continue), every tab, and request, Accept, chat, send a message, back to Crew. Also: chat locked for non-Crew, Report and Block in the other-profile overflow. All pass.
- One full run showed `SupabaseBackendTests.localSignOutClearsStorageAndUsesLocalScope` failing once (it saw a `/auth/v1/token` request where it expected `/auth/v1/logout`). It passed on every rerun, including the final full run. That test uses shared URLProtocol state and was not touched. Treat it as a latent flake in the foundation tests.
- XcodeBuildMCP had no tap or swipe tool in this session, so the click-through is done by the XCUITest above and the screenshots come from the gallery script. I looked at every gallery screenshot (as contact sheets) and fixed: doubled button text (shadow was applied to the label), artwork overflowing grid cells, invisible placeholders in search fields, truncated role chips, a white splash capture, an empty Settings header, and a CTA hidden under the tab bar.

## Deviations from Figma

- System `TabView`, icon-only (decision 32). On the iOS 26 SDK the bar is the floating glass bar; Figma shows a flat charcoal bar. The custom `UITabBarAppearance` is applied but iOS 26 mostly ignores it.
- Photos are gradients with SF Symbols. Figma shows photography. The mascot and character SVGs from `docs/design/illustrations/vector` are not used yet (SwiftUI has no SVG renderer; they need conversion to PDF or asset-catalog vectors). The Suki eye is `eye.circle.fill`, the splash eye is an SF Symbol.
- Rough hand-drawn borders are approximated with a zigzag shape, not the Figma vector borders. No torn-edge headers, no film-strip frames.
- Poppins is not bundled. Form copy and bio use DM Sans (tokens list Poppins for helper and input text). Project title uses DM Sans Bold, not Poppins Bold.
- Figma sorted Search chips as salmon pills with topic words; the chips here are realm names plus "Motion design" and "Painting".
- Settings uses a plain list with SF Symbols, not the Figma row icons. Settings pages are simpler (no Collaboration Preferences, Connected Apps, Language and Region).
- Project detail has no collaborators strip, comments, ratings or "more like this" (decisions 24, 25).
- Chat bubbles use the token radii (three large corners, one 3 pt corner); the 3 pt corner points at the sender.

## Deviations from concept v2

- **Module names:** Entry and onboarding are one `KizukiOnboardingFeature` (concept: `KizukiEntryFeature`). Chat is its own `KizukiChatFeature` (concept: inside Home). Report, block and blocked list live in `KizukiSettingsFeature` (concept: `KizukiAccountFeature`). `KizukiPlatform` (location, notifications) and `KizukiEmbeds` are not created; the primers are UI only and embeds are mock cards.
- **State:** one shared `AppStore` in Core rather than a model per feature. It is the only thing views read. Simpler for a prototype; the concept's per-feature models can split off when live data arrives.
- **Session:** the prototype root bypasses `AppSession` and the entry phases (verify email, password recovery, `missing_fields` sheet). The foundation session code is kept and still used for `-live` and UI-test launches.
- **Onboarding:** order and content differ from 5.1. No email verification step, no pairwise taste choice, no profile photo step, no "your work" links step, no loader and preview with recommendations. Roles come after realm, taste before favourites, and notification primer precedes location primer (the brief's order; concept puts location first).
- **Create chooser:** two options only ("Create a project", "Post a collab"), per the brief. "Get discovered" is replaced by Edit profile on the Profile tab.
- **Request and invite:** composer supports join (from a project) and ask-to-collaborate (from a profile). Invite is a demo button in the owner view only; the invite sheet is not built.
- **Request detail:** Decline has no optional private reason sheet. Withdraw is immediate. Block from the request detail overflow also pops the screen.
- **Home:** no "see more" full lists. Recommendation reasons are generated by the fixture backend with a simple rule, not by `recommend`.
- **Search:** no people row, no Recent list, no seeded-tag chips; chips filter by realm and a few tags.
- **Accent colour:** `KizukiTheme.accent` changed from `#FF4B1E` to Kizuki Orange `#E95833` to match the tokens doc. `KizukiTheme.ink` (which was cream) is now Figma's brown Ink `#371F1D`; `FoundationRoot` and the old button style now use `cream`. The only edit to existing foundation UI code.
- **Colour scheme:** the prototype root locks dark mode. Concept 2.2 asks to remove the global lock at K01; the foundation root still has its own lock.
- **TestSupport:** concept says fixtures are Debug-only; done. A Release build links an empty `KizukiTestSupport`. A release-build symbol check (C-34) is not added yet.

## Open UX questions

1. Should availability and work mode be visible on other people's profiles? The prototype follows decision 50 (owner-only). Figma draws an availability card on a public profile.
2. Should requests to a person (not a project) exist at all in v0? The prototype allows "Ask to collaborate" from a profile with no project.
3. When Accept opens the chat immediately, is that too abrupt for an owner clearing several requests? Alternative: stay in Requests and show "Open chat".
4. Does a Crew member need an explicit "Remove from Crew" (distinct from Block)? Not designed.
5. Two Suki segmented controls (Crew/Requests/Create plus Incoming/Sent) stack on one screen. Is Sent better as a filter inside the list?
6. Which states appear in the list? The prototype shows all five (pending, accepted, declined, withdrawn, expired). Should resolved ones fold away after some time?
7. Compensation is a three-way label (Paid, Passion, Open). Is a project allowed to be "Open to either"? The owner form currently offers all three.
8. Where does "Get discovered" (edit creative profile) live now that the chooser has two options? Profile > Edit is the prototype's answer.
9. Taste cards: the prototype shows six placeholder moods. The real set (and who tags it) is still a launch blocker (decision 21).
10. Embed cards: tapping Play in the real app opens a locked web view. Should the card show a still and open in-app, or hand off to the host app?
11. Tab bar: accept the floating iOS 26 glass bar, or force a flat bar to match Figma on iOS 26?
12. Search is photos only. Should people appear in results at all, or only via the Home people grid?
13. Chat opens only for Crew. What does a user see when they follow an old deep link to a chat they left or blocked? The prototype shows a locked state.

## Round 1 revisions (2026-10-25)

Related: [[2026-10-24-architecture-round-1-interview]] (decisions 51 to 57), `docs/design/icons/README.md`, [[2026-10-25-icon-sheet-reference]]. This section overrides the older text above where they disagree (for example "Ask to collaborate", owner-only availability, "Get discovered is replaced by Edit profile", and the screen counts).

### What changed

| # | Decision | Change |
| --- | --- | --- |
| 51 | Availability on every profile | `Person` now has `availability` (fixtures vary it across the three bands). Every profile shows "X is available to collab" plus the band. Work mode and pay preference stay owner-only (concept rule, unchanged): only my own profile shows them, with the note "Everyone sees your availability. Only you see work mode and pay preference." **Schema note:** `availability_band` is now a public field. The concept's pgTAP privacy assertions (C-01) and the "reasons never use availability" rule need updating before the live backend. |
| 52 | Wording | Profile button is **"Wish to Collab"** (disabled "Wish sent" after sending). Project button is **"Join project"**. New `RequestKind` (`wishToCollab` when `projectID == nil`, else `joinProject`) with labels, exposed as `CollabRequest.kind`. Fixtures gain two Wish to Collab requests (one incoming from Ada Nowak, one outgoing to Ivo Berg). Requests lists show an orange kind label ("WISH TO COLLAB" / "JOIN PROJECT") and a line like "Ada wishes to collab" when there is no project. Request detail has a Type row. The composer title is "Wish to Collab with Ivo" or "Join project". If someone has already sent me a request, their profile shows "Review their request" instead. `pendingRequest` and the backend duplicate check now look at outgoing requests only (an incoming wish no longer blocks my own). |
| 53 | Accept opens the chat | Already built (Accept in the list and in the detail both call `router.openConversation`). Kept. A new unit test covers accepting a Wish to Collab (chat opens with no project title). |
| 54 | Remove from Crew | New `RequestRepository.removeFromCrew`, `AppStore.removeFromCrew`, new request state `ended` ("Left the Crew"). Accepted requests with that person become `ended`, the conversation is deleted, the person is not blocked and can be asked again. Reachable from the Crew card (ellipsis menu), the chat overflow and the profile overflow (Crew members only). A confirmation dialog ("Remove Aya from your Crew? The chat closes. Aya isn't blocked and can send a new request.") sits in front of it. On iOS 26 the dialog is a small floating sheet with no Cancel button: tapping outside cancels. Block is untouched and stays separate. |
| 55 | Search | Grid shows photos and short videos only. The query matches captions and tags, never people (it used to match author names and roles). Placeholder is "Search photos & videos". `CollabPhoto.videoSeconds` marks videos. Every third fixture post is a "video": a play badge plus a `0:12` style duration over the placeholder tile, also in the post viewer (large badge) and on the profile grid. No video files, no playback. VoiceOver reads "Short video, 0:12: caption". |
| 56 | Tab bar | System `TabView` kept (floating glass bar on iOS 26). SF Symbols replaced by Kizuki template vectors. See "Icons" below. |
| 57 | Get discovered | Profile completeness card on the own Profile tab. See "Get discovered" below. |
| New | Home header | The Figma blue "k" logo (22 x 42) and the Figma gear and messages icons, laid out as in the Feed / Discovery Page nav bar. See "Home header and Suki" below. |
| New | Suki mascot | The Suki creature on the Suki tab. See below. |
| 7 | App icon | Set from the Figma artwork. See "App icon". |

Also changed: the splash screen now uses the Figma wordmark (`614:262`) and the sign-in screen uses the K mark, instead of an SF Symbol eye and plain text.

### Icons (decision 56)

**Source honesty first.** Figma frame `concept_8.6` (`614:260`) holds the brand work (wordmark, K mascot, app icon, mascot pair, splash mocks). It does **not** contain the tab icon set shown on the reference sheet. I searched all three pages of the file by layer name and by screenshot. So the five tab icons and the alternates are **traced from the reference JPG** (potrace on a 6x upscale, one-colour). They are crisp at tab-bar size but they are traces, not the designer's paths. The designer should export the originals; swapping is a file copy (see `docs/design/icons/README.md`). The wordmark, K marks and app icon are real Figma vectors (SVG).

Exports: `docs/design/icons/` (README with node ids and formats; `figma/` raw SVG exports; `brand/` cleaned logos; `app-icon/` SVG and 1024 PNG light, dark, tinted; `sheet-traced/` all 26 sheet icons as SVG plus a contact sheet; `tools/`). In the app: `KizukiDesignSystem/Resources/KizukiIcons.xcassets` (SVG, Preserves Vector Data, template rendering for the tab icons) read through `KizukiIcon`.

| Tab | Icon (sheet position) | Why | Alternate to swap in |
| --- | --- | --- | --- |
| Home | Polaroid frame with a star on a second card (column 1, row 1) | Home is a feed of project and people cards. A framed card with a spark says "something worth a look". Reads at 28 pt, and the card shape differs from every other tab. | Four tiles with one starred (`alt-home-tiles-star`), or the K mark from Figma (brand anchor, but a letter-like shape reads less as "home"). |
| Search | Magnifier with a four-point star lens (column 2, row 1) | The most legible search metaphor, and the star ties it to discovery. I kept the eye out of Search on purpose so Suki's eye stays unique. | Magnifier with rays around an eye (`alt-search-eye-rays-magnifier`), or the blob lens (`alt-search-blob-lens`). |
| Suki | The current eye in a solid disc (top row, centre) | The centrepiece, as briefed. The disc is the heaviest shape in the bar, which marks the product's name tab. The eye is a knock-out, so the tint shows through. | Plain almond eye with a starred iris (`alt-search-eye-star`), lighter but loses the disc. |
| My Projects | Folder with a star (column 4, row 3) | Keeps the "archive of what I make" idea of the current drawer, with the star used as "the made thing". | Open book with a star (`alt-projects-open-book`) or cards with a bookmark (`alt-projects-cards-bookmark`). |
| Profile | Bust with a starburst behind the head (column 5, row 4) | A person silhouette is the clearest "me", and the burst echoes Get discovered and the star motif. Strong silhouette at small size. | Head with a closed eye and earrings (`alt-profile-head-closed-eye`), warmer but its detail disappears under 30 pt. Horned head and medusa are fun but too busy for a tab. |

States. iOS 26 draws the selected tab in the tint (Kizuki orange `#E95833`) on a lighter glass capsule; unselected icons are near white. I checked screenshots on the Home, Suki and Profile tabs (see paths below): selected and unselected are clearly different in colour and in the capsule behind them, and the bar stays legible in dark mode (the app is dark-locked), including over the light Home cards. The sheet's blue and red accents are dropped (one-colour template images). Every tab image carries a VoiceOver label (Home, Search, Suki, My Projects, Profile) and the system adds the selected trait. A UI test taps each tab and asserts exactly one is selected.

Limits. The glass bar ignores `UITabBarAppearance` colours, so unselected colour cannot be tuned beyond what the system gives. If the user wants a stronger unselected state, the fix is an outline variant per icon from the designer, not code.

### App icon (item 7)

Found: Figma `614:319` "icon - edid this" (cream `#F2EEE7` tile, `#1A1A1A` K with eye cut-outs). Set in `ios/App/Assets.xcassets/AppIcon.appiconset` as one 1024 icon plus **dark** (orange `#FF6139` K on `#1A1A1A`, from the orange K variant `614:366`) and **tinted** (white K on black). PNGs have no alpha. Figma shows a rounded tile; iOS applies its own mask, so the shipped art is the same artwork on a full-bleed square. `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` is in `project.yml`. Verified the built app contains the icon files. Not verified: the Home Screen render of the dark and tinted variants (a simulator run with those appearances was not done).

### Get discovered (decision 57)

**Placement: a completeness card on the own Profile tab**, titled "Get discovered", with a progress bar, "4 of 5" and five rows (short bio, roles, favourites, link your work, post your first collab). Each open row is one tap: the first four open Edit profile, the last jumps to Suki > Create. It disappears at 5 of 5. The fixture user starts without a bio, so it shows in the gallery.

Why here, against the core loop (find people, ask, get a yes, chat, collab, post, be found):
- Being discovered is the supply side of the loop. Recommendations, requests and replies only work if a profile has roles, a bio, work and favourites. The card turns "profile is thin" into a visible next step at the place where people already look at themselves.
- **Onboarding** is already 12 steps. Adding a step costs activation, and a bio or links asked before the user has seen anyone is the weakest moment. It also cannot cover "post a collab", which only makes sense later.
- **A Home prompt** would compete with Recommended projects and People you might like, the screen that drives the loop. The "Finish your project" card already uses that slot for start-intent users.
- The card is not a tab or a chooser option, so the Create sheet stays at two options (as briefed) and Profile > Edit still exists for the full form.
- It is also the natural home for later nudges (a profile photo step, the work-links step that the concept's onboarding has and the prototype skips).
Risk: users who never open Profile never see it. Mitigation if that shows in testing: show a one-line pill on Home until 3 of 5. Alternative if the user prefers it: an onboarding step "Show your work" (links and bio, skippable) before the ready screen.

### Home header and Suki mascot (two follow-up requests)

**Home logo.** Figma App (Copy) `nPqXTMCtd3OVZTSU7Y2uN3`, frame `1312:8064` "Feed / Discovery Page", layer `1312:8143` "Logo" (22 x 42.23, blue `#3F7BE2`, dark `#1A1A1A` eyes). Its path data is the same K mark as the Playground (Copy) K (`614:372`), only recoloured. Exported as SVG (`docs/design/icons/figma/feed-logo-1312-8143.svg`, clean copy in `brand/`), shipped as an original-colour vector asset `KizukiFeedLogo`. The nav-bar icons (`1312:8142`, settings-rounded and chat-messages, 24 pt, 20 pt apart) are exported too and replace the SF Symbols on every top bar. Layout follows the nav bar: logo 5.5 pt in from the title margin, nudged up 3 pt, icons 24 pt in 44 pt targets, nudged down 7 pt as in the Figma frame, trailing margin 13 pt. The bar is 62 pt below the status bar as before. Only the Home bar uses the logo; other tabs keep their title.

**Suki mascot.** Chosen: the Suki creature (`docs/design/illustrations/vector/illustration-12.svg`, Figma App (Copy) `614:9214`), a real vector and the character the product is named after. It is one flat shape in the brand orange, so it needs no recolouring on the charcoal background (shipped as a template vector tinted `#E95833`). Used in two places: a greeting beside the "Your Crew" title when the Crew has people, and as the large illustration in empty states (Crew: "Your Crew starts with a yes"; Requests: "No requests yet" and "Nothing sent yet"). Not on the Create chooser: it already has the two Blobatar avatars and a third figure would crowd it. VoiceOver: the mascot is hidden, and the empty-state title and message are read as one element. **Alternative:** the medusa head from the sheet (right column, row 2). Not chosen because the only vector I have is my trace from the JPG (the real one is not in the Figma file), it is white line art with fine snakes that turns to noise under 100 pt, and it is not the Suki character. If the user wants it, it is `docs/design/icons/sheet-traced/alt-profile-medusa.svg`; it would fit better as a Profile or Create accent than as the Suki greeting.

### Other fixes found on the way

- Get discovered rows only registered taps on their text; fixed with a full-row hit area (found by the new UI test).
- `SupabaseBackendTests.localSignOutClearsStorageAndUsesLocalScope` failed in three full runs in a row this session (the flake noted above). It took the last captured request, which can be a late refresh call. It now picks the logout call itself. Assertions are the same (path and `scope=local`). Passes since.
- `docs/design/icons/tools/` holds the scripts that built the icons. They have absolute `/tmp` paths and are provenance, not a build step.

### Not done or open

- Original Figma vectors for the tab icons (see above). Needs the designer to export them.
- Outline variants for unselected tab states (not in the sheet).
- Release-config build was not run (same Staging validation stop as round 1). All new prototype code is Debug-only or in design-system, the new assets are in the design-system bundle (also in Release, about 25 KB).
- App icon dark and tinted renders on a Home Screen were not checked.
- Video: placeholders only; there is no playback, trimming or length limit in the post form. The 60 s cap is only a fixture bound.
- No profile photo step or "link your work" step in onboarding (still concept 5.1 differences).
- Availability is public in the prototype only; the privacy and schema docs have not been edited.
- The confirmation dialog has no Cancel button on iOS 26 (system behaviour); tapping outside cancels.
- Two Suki segmented controls still stack (open question 5 above).

### Verification

Everything below ran on the iPhone 17 Pro simulator (UDID `491ABF02-...`). The iPhone 16e was not touched.

- Regenerated with `scripts/generate-project.sh`. Kizuki-Local Debug build: clean.
- **Unit tests: 34 pass, 0 fail** (21 foundation; 13 in `PrototypeStoreTests`, 7 of them new: Remove from Crew keeps the person unblocked and closes the chat, Wish to Collab without a project, accepting a wish opens a chat, public availability, video fixtures and duration labels, Get discovered checklist, every `KizukiIcon` asset ships in the bundle). The gallery-script test also checks the new `suki-empty` id.
- **UI tests: 12 pass, 0 fail** (2 foundation; 10 in `PrototypeFlowUITests`). New or changed: each tab reports exactly one selected; Wish to Collab and availability on another profile, then sending it ("Wish sent"); "Join project" on a project; request lists name the kind; Remove from Crew (tapping outside keeps them, confirming removes them); search shows photo and short-video items; Get discovered row opens Edit profile; the profile overflow has no Remove from Crew for non-Crew people.
- One earlier full run executed only the old 4 prototype UI tests (Xcode used a stale test list); running the new ones by name worked and the next full run picked up all of them.
- Screenshot gallery re-run with `scripts/screenshot-gallery.sh`: **40 screens** (new id `suki-empty`) in `hub/prototypes/2026-10-25-<id>.png`, 1206 x 2622. I looked at them as contact sheets and cropped the tab bar at full size on Home, Suki and Profile. Most relevant: `home`, `search`, `search-post`, `suki-crew`, `suki-empty`, `suki-requests`, `suki-sent`, `request-detail`, `profile`, `profile-other`, `project-detail`, `request-form`, `splash`, `login`.

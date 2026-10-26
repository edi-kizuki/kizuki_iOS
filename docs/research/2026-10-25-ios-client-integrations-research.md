---
title: iOS client architecture, integrations and App Store safety research
created: 2026-10-25
tags: [project/kizuki, research, ios, app-store, architecture]
status: complete-v1
---

# iOS client architecture, integrations and App Store safety research

Related: [[playbook]], [[2026-10-24-architecture-round-1-interview]], [[2026-10-25-figma-full-walkthrough]]

Also see [[00-what-exists]] and [[2026-10-24-ios-build-readiness]].

Scope: research and recommendation only. No app code was written. Locked user decisions (#1–#28 in [[2026-10-24-architecture-round-1-interview]]) override older sources.

Labels used below:
- **[Apple]** = Apple primary source, fetched 2026-10-25.
- **[Vendor]** = a vendor's own docs or terms. Their claims, not independently verified.
- **[Repo]** = read from this repository.
- **[Inference]** = my reasoning, no direct source.
- **[Unverified]** = could not confirm from a primary source. Verify before relying on it.

## 0. Contents

1. Architecture and foundation review
2. Permissions up front (location, notifications)
3. Sign in with Apple, email, account deletion, 18+ gate
4. UGC: report, block, filtering, contact (Guideline 1.2)
5. Embeds (YouTube, SoundCloud, Bandcamp, Instagram, Letterboxd)
6. Taste data (TMDB, MusicBrainz, Cover Art Archive)
7. Placeholder imagery
8. TestFlight path
9. Risks and open questions
10. One-page recommendation (build / reuse / skip)

## 1. App architecture and foundation review

### 1.1 What exists [Repo]

- `ios/Packages/KizukiKit` with four targets: `KizukiCore` (config validation, `AppSession`, `Profile`, `SessionRepository`/`ProfileRepository` protocols), `KizukiInfrastructure` (`SupabaseBackend`, supabase-swift pinned `exact: 2.55.4`), `KizukiDesignSystem` (`KizukiTheme`, `KizukiButtonStyle`, `ProfileAvatar` with 32 bundled Blobatar PNGs and licence), `KizukiFoundationFeature` (one placeholder screen).
- App target: `ios/App/KizukiApp.swift`, hand-written `Info.plist`, three xcconfig environments (Local/Staging/Production), 3 schemes, release-config validation script.
- Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY: complete`, iOS 17.0 floor, iPhone only.
- Tests: 4 Swift Testing files (config, session, avatar, Supabase transport via `URLProtocol`) + 1 XCUITest file driven by `--ui-testing` launch args. Foundation report: [[2026-10-24-foundation-coding-report]].
- No `PrivacyInfo.xcprivacy`, no entitlements file, no purpose strings, no `ITSAppUsesNonExemptEncryption` key in `Info.plist` yet.
- Debug bundle id is `club.kizuki.ios.local`; Staging/Production use `club.kizuki.ios` (`Local.xcconfig`, `Base.xcconfig`).

### 1.2 Keep / change verdict on the foundation

Keep (good decisions, cheap to extend):

| Item | Why |
| --- | --- |
| `@MainActor @Observable AppSession` with generation guard against late responses | Matches Apple's Observation model; race-safe sign-out/profile load. |
| Repository protocols in `KizukiCore`, SDK only in `KizukiInfrastructure` | Features can be tested with fixtures and never import Supabase. |
| `AppConfiguration` rejects service-role keys and mismatched environment URLs | Strong safety rail for a production-backed project. |
| Keychain session storage, PKCE flow, per-environment storage key | Correct for Sign in with Apple + email. |
| Swift Testing for logic, XCUITest only for flows | Correct split (see 1.6). |
| Exact-version pin + committed `Package.resolved` | Reproducible TestFlight builds. |
| Bundled Blobatar PNG catalog, no SVG runtime, no remote host | Offline, deterministic, no third-party request at runtime. |

Change before feature work:

| Item | Change | Reason |
| --- | --- | --- |
| `UITestBackend` is a `#if DEBUG` struct inside `KizukiApp.swift` | Move to a new `KizukiTestSupport` target with fixture repositories (users, projects, collab photos, requests, chats). | Decision #18 needs seeded mock data; one fixture layer should serve previews, unit tests, UI tests and any Demo build. |
| `FoundationRoot` uses `.preferredColorScheme(.dark)` globally | Remove the global lock; drive colour from tokens. | Home feed in Figma is dark cards on a pale blue-grey background ([[2026-10-25-figma-full-walkthrough]]). Token source is still unverified. |
| `Profile` has 4 fields | Add domain models and repository protocols per feature (see 1.3). | Foundation is intentionally minimal. |
| Single `Info.plist` for all configs; `Info-Local.plist` for Debug | Add purpose strings, `ITSAppUsesNonExemptEncryption`, URL scheme to both. | Missing for review; see sections 2 and 8. |
| `KizukiButtonStyle` is the only component | Build chips, cards, tab bar, avatar tiles, sheets in `KizukiDesignSystem`. | Needed by every tab. |
| Bundle id differs in Debug (`.local`) | Register `club.kizuki.ios.local` as its own App ID with Sign in with Apple and Push, or run Apple sign-in only on Staging/Production builds. | Capabilities are tied to the App ID. [Inference] |

### 1.3 Proposed module layout (extends KizukiKit; one package, many targets)

```
KizukiKit/Sources
  KizukiCore            domain models, repository protocols, AppSession, AppRoute enums, pure logic
  KizukiInfrastructure  Supabase repos (auth, profiles, projects, requests, chat, reports, storage)
  KizukiPlatform  (new) LocationService, NotificationService, DeepLinkParser, PermissionPrimer state
  KizukiCatalog   (new) TMDB + MusicBrainz + CoverArt clients behind TasteCatalogRepository
  KizukiDesignSystem    tokens, components, avatar, remote image view, tab bar
  KizukiEmbeds    (new) URL -> embed descriptor (pure), WKWebView wrapper, allowlist
  KizukiTestSupport (new) fixtures + fake repositories (never linked into Release)
  Features (one target each, depend only on Core + DesignSystem + Platform):
    KizukiAuthFeature         sign-in, email, age gate, delete-account entry
    KizukiOnboardingFeature   realm/roles/intent, permission primers, taste picker, profile setup
    KizukiHomeFeature         feed, recommended projects, people-you-might-like
    KizukiSearchFeature       search bar, chips, 3-col grid, post viewer
    KizukiSukiFeature         matches, requests (in/out), create project/collab entry
    KizukiMyProjectsFeature   drafts, published, past; project editor
    KizukiProfileFeature      own + other profile, widgets, edit
    KizukiInboxFeature        conversation list, chat (only after accepted request)
    KizukiSafetyFeature       report sheet, block action, blocked list
    KizukiSettingsFeature     settings, notifications toggle, legal, delete account
App target (composition root): builds dependencies, TabView, router, deep links
```

Rules:
- Features never import `KizukiInfrastructure` or each other. The app target wires them. [Inference]
- Cross-feature navigation (project -> profile -> project) would create import cycles. Fix with an `AppRoute` enum in `KizukiCore` (`.profile(UUID)`, `.project(UUID)`, `.conversation(UUID)`, `.request(UUID)`, `.reportSheet(target)`). Each tab's `NavigationStack` registers one `navigationDestination(for: AppRoute.self)` supplied by the app target. [Inference]
- Ten feature targets is more `Package.swift` boilerplate than a solo build needs. Acceptable cheaper variant: merge Safety+Settings into `KizukiAccountFeature`, and Auth+Onboarding into `KizukiEntryFeature` (7 feature targets). Keep per-tab separation because it keeps parallel agent work conflict-free. [Inference]

### 1.4 State management

- Use Observation (`@Observable`), no third-party architecture library. Apple: SwiftUI supports Observation from iOS 17, with benefits including tracking optionals/collections and using `@State`/`@Environment` instead of object-based equivalents. [Apple] https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro
- Pattern per screen: `@MainActor @Observable final class XModel` with `init(repo: any XRepository)`; view owns it with `@State`. One state enum per async load (`loading/loaded/empty/failed`), the same shape `AppSession` already uses. [Inference, extends repo pattern]
- App-wide services in one `Dependencies` struct (protocol-typed repositories) placed in the SwiftUI environment from the app target. Models take what they need through `init`, never read `Dependencies` directly. Keeps tests free of environment setup. [Inference]
- Do not add TCA/Redux. iOS 17 floor and a 5-tab CRUD app do not need it. [Inference]

### 1.5 Navigation and deep links

- `TabView(selection:)` with an `AppTab` enum. The `Tab { }` initialiser, `.sidebarAdaptable` and `Tab(role: .search)` are iOS 18+, so with the iOS 17 floor use `.tabItem` + `.tag`. [Apple, availability metadata: `Tab` iOS 18.0, `sidebarAdaptable` iOS 18.0, `tabBarMinimizeBehavior` iOS 26.0] https://developer.apple.com/documentation/swiftui/tab
- Figma tab bar is icon-only with a larger centre "Suki" eye ([[2026-10-25-figma-full-walkthrough]]). A system `TabView` cannot size one item differently. Two options: (a) system bar, icons only, accessibility labels set; (b) hide the system bar (`.toolbar(.hidden, for: .tabBar)`) and draw `KizukiTabBar` via `safeAreaInset(edge: .bottom)`. Recommend (a) for v0 TestFlight, (b) only if the user insists on the pixel match. [Inference]
- One `NavigationStack(path:)` per tab; `NavigationPath` lets a stack hold mixed types. [Apple] https://developer.apple.com/documentation/swiftui/navigationpath and https://developer.apple.com/documentation/swiftui/navigationstack
- Router: `@MainActor @Observable AppRouter { selectedTab; paths[AppTab] }` with `open(_ route: AppRoute)`.
  - DMs icon on Home pushes `.inbox` on the Home stack. Chat link: `selectedTab = .home; path = [.inbox, .conversation(id)]`.
  - Incoming request link: `selectedTab = .suki; path = [.request(id)]`.
- Entry points: `onOpenURL` for a custom scheme `kizuki://` (works with no domain), and `UNUserNotificationCenterDelegate.didReceive` mapping `userInfo["route"]` to `AppRoute`. [Apple] https://developer.apple.com/documentation/swiftui/view/onopenurl(perform:) . Universal Links need Associated Domains plus an `apple-app-site-association` file on a domain the user controls; the domain is not named in any source. [Unverified, open question]
- Route guard: a route to a conversation must verify the request is accepted (decision #11); the check belongs in the repository/RLS, not only in UI. [Inference]

### 1.6 Testing strategy

- Swift Testing for models, parsers (embed URL allowlist, TMDB/MusicBrainz decoding), router, config; already used in all 4 unit test files [Repo]. Swift Testing runs side by side with XCTest. [Vendor: swiftlang] https://github.com/swiftlang/swift-testing
- UI automation: the Swift Testing README does not claim UI-test support; XCUITest remains the UI automation framework [Inference from Apple tooling; Unverified in README]. Keep `XCUIApplication` flows on launch-arg fixtures, as `FoundationUITests` does.
- Minimum v0 flow tests: sign-in (fixture) -> onboarding incl. permission primers (system alerts via `addUIInterruptionMonitor`) -> Home -> send request -> (fixture) accept -> chat; report + block hides content; delete account returns to entry.
- Pure-logic coverage targets: `EmbedResolver`, `AgeGate`, `RequestState` machine, route parsing.
- Backend contract tests stay in `Tests/SupabaseBackendTests.swift`; RLS tests in `supabase/tests` (pgTAP) [Repo].
- Accessibility: keep the XXXL dynamic type UI test pattern for every tab root. [Repo]

### 1.7 Offline and caching scope for v0

| Area | v0 scope |
| --- | --- |
| Auth session | Keychain (exists). |
| Feed, search, profiles | No offline. Online-only, load/empty/error states with retry. |
| Images | One `RemoteImage` view on a configured `URLCache` (e.g. 50 MB memory / 300 MB disk). No image SDK. Revisit Nuke if scroll jank appears. [Inference] |
| Drafts | Server-side rows with `status = draft`, so My Projects "Drafts" works across devices. |
| Onboarding progress | In-memory plus server profile fields; if `UserDefaults` is used, declare it in the privacy manifest (section 8). |
| Chat | Online-only. Realtime subscription optional; polling on appear is enough for v0. [Inference] |
| Taste catalog results | In-memory cache per session; persist only the selected IDs and display names. |
| Offline queue / SwiftData | Skip. |

### 1.8 Open architecture issue: "mock data on TestFlight"

Decision #1 says TestFlight "on real local data"; #10 says the Supabase project is production and development is local; #18 says no real data, seeded mock data. A TestFlight build cannot reach a Mac's `127.0.0.1:54321`, and `AppConfiguration` forbids non-local backends in Debug and forbids Staging against the production host [Repo].

Options (user must choose; see section 9):
1. A cloud **staging** Supabase project seeded with mock data. Real auth (Apple + email), real RLS. TestFlight uses the Staging scheme. Costs a second Supabase project.
2. A **Demo** build configuration using bundled fixtures (`KizukiTestSupport`) with a fake auth session. Zero backend risk, but Sign in with Apple and email are not exercised, and testers cannot message across devices.
3. Seed mock rows into the production project behind an `is_mock` flag. Rejected: violates the user's own "production" framing and pollutes real data. [Inference]

Recommendation: option 1; keep option 2 for previews, UI tests and App Review demo fallback.

## 2. Permissions up front (location, notifications)

User decision #8: location and notifications are requested in onboarding. This section says how to do that without rejection risk.

### 2.1 What the rules say

- Apple's HIG: "Request permission only when your app clearly needs access... Ideally, wait... until people actually use an app feature that requires access." and "Avoid requesting permission at launch unless the data or resource is required for your app to function." [Apple] https://developer.apple.com/design/human-interface-guidelines/privacy
  - This is guidance, not a rule that triggers rejection by itself. The up-front ask is allowed; it is the weakest-practice option. [Inference]
- 5.1.1(iii): "Apps should only request access to data relevant to the core functionality of the app." [Apple] https://developer.apple.com/app-store/review/guidelines/
- 5.1.1(iv): "Apps must respect the user's permission settings and not attempt to manipulate, trick, or force people to consent to unnecessary data access... Where possible, provide alternative solutions... if a user declines to share Location, offer the ability to manually enter an address." [Apple] same URL.
- 5.1.2(i): "Your app may not require users to enable system functionalities (such as push notifications, location services, tracking) in order to access functionality, content, use the app..." [Apple] same URL. **Denying either prompt must never block onboarding or any tab.**
- 5.1.5: "Use Location Services in your app only when it is directly relevant to the features and services provided by the app... explain the purpose in your app." [Apple] same URL.
- 5.1.1(ii): purpose strings must "clearly and completely describe your use of the data." [Apple] same URL.
- Core Location doc: "If you make a request immediately at app launch, or in a part of your app that doesn't clearly use location data, the person might misinterpret your intent and deny the request." [Apple] https://developer.apple.com/documentation/corelocation/requesting-authorization-to-use-location-services
- Notifications doc: ask "in a context that helps people understand why your app needs authorization"; subsequent requests do not prompt. [Apple] https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
  - With `.provisional` "you can request authorization when your app first launches" and the person is asked only when they receive a notification. [Apple] same URL.

### 2.2 Pre-permission ("pre-alert") screen: Apple's own constraints

Apple HIG, section "Pre-alert screens" (applies to camera, microphone, location, contacts, calendar, tracking): [Apple] https://developer.apple.com/design/human-interface-guidelines/privacy
- "Include only one button and make it clear that it opens the system alert."
- Do not title it "Allow". Use "Continue" or "Next".
- "Don't include additional actions in your custom screen... For example, don't provide a way for people to leave the screen or window without viewing the system alert — like offering an option to close or cancel."
- For the tracking alert, Apple states that misleading pre-screens "will lead to rejection by App Store review." Listed prohibited designs: offering incentives, a screen that looks like a request, an image of the alert, annotating the screen behind the alert. This sentence is written about tracking; apply the same discipline to location. [Apple, scope caveat mine]

Conflict with Figma: frames `1312:13191` / `1312:13193` show two loose buttons "ALLOW CONNECTION" and "MAYBE LATER" next to the location screen ([[2026-10-25-figma-full-walkthrough]]). "ALLOW..." and a skip button both violate the HIG pre-alert rules above for location. Change the copy and structure. [Inference]

### 2.3 Concrete compliant design

Order: after account creation and the 18+ gate, before taste/profile steps. Two separate screens. Never both in one screen.

**Screen A: Location**
- Headline: "Find creators near you" (Figma copy, fine). Body: "Kizuki uses your location once to set your city, so we can show people and projects nearby. We store your city, not your coordinates."
- One button: "Continue". It calls `CLLocationManager.requestWhenInUseAuthorization()`.
- No "Skip", no "Maybe later" on this screen. The system alert's "Don't Allow" is the opt-out.
- Result handling:
  - `authorizedWhenInUse` -> `requestLocation()` once (one-shot, accuracy reduced), reverse-geocode with `CLGeocoder` to city + country, store city only, drop coordinates. Show city for confirmation, editable. [Apple] https://developer.apple.com/documentation/corelocation/cllocationmanager/requestlocation()
  - `denied` / `restricted` / approximate-only -> same next screen: "Where are you based?" manual city entry. Required by 5.1.1(iv). City is also required by the matching rules (decision #14/#15 list city).
- Info.plist: `NSLocationWhenInUseUsageDescription` = "Kizuki uses your location once to set your city and show creators and projects near you." Add `NSLocationDefaultAccuracyReduced = true` so the prompt defaults to approximate. [Apple] https://developer.apple.com/documentation/bundleresources/information-property-list/nslocationdefaultaccuracyreduced
- Do not request `Always`. Do not run continuous updates. No background location mode.
- Privacy label: Coarse Location, linked to user, purpose App Functionality. [Inference; confirm in App Store Connect]

**Screen B: Notifications**
- Headline: "Stay in the loop". Body: "Get notified when someone accepts your request or sends you a message. You can change this any time in Settings."
- One button: "Continue" -> `UNUserNotificationCenter.requestAuthorization(options: [.alert, .sound, .badge])`.
- A secondary "Not now" text link is lower risk here than on location, because HIG's pre-alert list does not name notifications. Keep it visually secondary. [Inference]
- No Info.plist purpose string exists for notifications; the system alert has no developer text. The pre-screen copy carries the explanation. [Apple, alert has no usage-description key; source: asking-permission doc above shows only the API call]
- Remote push also needs the Push Notifications capability (`aps-environment`) and an APNs key on the server. For v0 with mock data, schedule local notifications only, or skip the capability until a server sender exists. [Inference]
- Fallback if opt-in is low or reviewers push back: switch to `.provisional`; it still satisfies "ask during onboarding" without a modal. Needs user sign-off since decision #8 implies the explicit prompt. [Inference]

**After denial (both)**
- Onboarding continues. No nag screen. Never re-call `requestAuthorization`; the system ignores repeat calls. [Apple] https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
- Settings screen shows status and an "Open Settings" button using `UIApplication.openSettingsURLString` (or `openNotificationSettingsURLString`). [Apple] https://developer.apple.com/documentation/uikit/uiapplication/opennotificationsettingsurlstring
- Notifications off: the Inbox and Suki tabs show an unobtrusive banner "Turn on notifications to hear when requests are accepted", dismissible, shown at most once per session. Everything remains usable.
- Observe status changes on `scenePhase == .active` and refresh.

**Review-submission hygiene**
- App Review notes: state that both prompts occur in onboarding and both are optional. [Inference]
- Do not gate "Create project" or "Send request" on either permission.
- Test with the permission denied in XCUITest (`addUIInterruptionMonitor`) so denial paths do not regress.

Rejection risk estimate: low for notifications; low-to-moderate for location, mostly if the pre-screen has an allow-style button, a skip that avoids the alert, no manual fallback, or location is not visibly used afterwards. Use the city on Home ("Berlin, DE") and in match reasons so 5.1.5 relevance is demonstrable. [Inference]

## 3. Sign in with Apple, email, account deletion, 18+ gate

### 3.1 Guideline 4.8 (login services)

- Text: apps that use "a third-party or social login service (such as Facebook Login, Google Sign-In, Log in with X, Sign In with LinkedIn, Login with Amazon, or WeChat Login) to set up or authenticate the user's primary account" must also offer an equivalent login service that limits collection to name and email, lets users hide their email, and doesn't collect interactions for advertising without consent. [Apple] https://developer.apple.com/app-store/review/guidelines/ (4.8)
- Not required if the app "exclusively uses your company's own account setup and sign-in systems." Same URL.
- Applicability for v0 (Apple + email): 4.8 is **satisfied**. Sign in with Apple is itself the compliant equivalent service; email/password is Kizuki's own system. [Inference]
- Decision #13 adds Google later. When Google ships, 4.8 applies in full. Keep Sign in with Apple on the same screen with equal prominence. [Inference]
- HIG: if you don't use Sign in with Apple prefer passkeys; also "Delay sign-in for as long as possible." [Apple] https://developer.apple.com/design/human-interface-guidelines/managing-accounts . Kizuki is account-based by nature (5.1.1(v) allows requiring login when accounts are core). A signed-out browse mode is not needed. [Inference]
- Use `ASAuthorizationAppleIDButton` / SwiftUI `SignInWithAppleButton` with scopes `.fullName`, `.email`. Apple returns name only on first authorisation; Supabase says the identity token omits full name, so save it from the credential client-side with `updateUser`. [Vendor: Supabase] https://supabase.com/docs/guides/auth/social-login/auth-apple
- Native path in supabase-swift: `client.auth.signInWithIdToken(credentials:)` exists in the pinned v2.55.4 (`Sources/Auth/AuthClient.swift`). [Repo-cache check] Use a random nonce (hash in the Apple request, raw in Supabase). Native-only needs no 6-monthly secret rotation; OAuth/web flows do. [Vendor: Supabase, same URL]
- Private relay email: addresses end `@privaterelay.appleid.com`; to email those users the sender domain must be registered with Apple and use SPF. Daily limit 100 emails per relay address. [Apple] https://developer.apple.com/documentation/signinwithapple/communicating-using-the-private-email-relay-service. Implication: auth/transactional email to Apple users depends on domain registration; account-linking by email is unreliable. [Inference]
- Do not auto-link an Apple account and an email account just because the emails match unless the email is verified. [Inference, security]

### 3.2 Email sign-in and App Review

- Guideline 2.1: "If your app includes account-based features, provide either an active demo account or fully-featured demo mode" and "Enable backend services so that they're live and accessible during review." [Apple] https://developer.apple.com/app-store/review/guidelines/ (2.1)
- If email sign-in is magic-link or emailed OTP only, the reviewer cannot receive mail. Offer **email + password** (or a pre-created demo account with password and a reviewer-only path). [Inference]
- Magic links on iOS need a custom URL scheme or Universal Links; a 6-digit OTP via `signInWithOTP`/`verifyOTP` avoids that. Both exist in the pinned SDK. [Repo-cache check] Recommend: password for App Review account; OTP code as the main flow for real users. Needs user decision (section 9).
- App Review needs the Supabase project that the build points at to be live and seeded (ties to 1.8).

### 3.3 Account deletion (5.1.1(v))

- Rule: "If your app supports account creation, you must also offer account deletion within the app." [Apple] https://developer.apple.com/app-store/review/guidelines/
- Apple's deletion page: [Apple] https://developer.apple.com/support/offering-account-deletion-in-your-app/
  - Easy to find, typically in account settings.
  - Must delete the account record and associated personal data, "only offering to temporarily deactivate or disable an account is insufficient."
  - Includes user-generated content shared with others: photos, text posts, reviews.
  - Confirmation allowed (e.g. email code). Must not be "unnecessarily difficult". A phone call/email/chat-support flow is not allowed for non-regulated apps.
  - May take time if you tell the person how long and confirm when done. If you retain data by law, say what.
  - "Apps that support Sign in with Apple should use the Sign in with Apple REST API to revoke user tokens."
- Implementation for Kizuki [Inference, built on the sources above]:
  1. Settings > Account > "Delete account" -> explain what is removed (profile, projects, collab photos, requests, messages you sent, blocks), confirm with a destructive button, re-authenticate (Apple: re-run Sign in with Apple; email: password/OTP).
  2. Call an Edge Function with the user's JWT. The function uses the service-role key (server only) to: delete storage objects, delete rows (cascade from `auth.users`), call Apple revoke if the identity is Apple, then `auth.admin.deleteUser`. The app never holds a service-role key (`AppConfiguration` already rejects one). [Repo]
  3. `supabase-swift` has `auth.admin.deleteUser(id:)`, but it needs the service role and must not run in the client. [Vendor: Supabase] https://supabase.com/docs/reference/swift/auth-admin-deleteuser
  4. Apple token revocation needs the Apple `.p8` key, Team ID, Key ID and a refresh/authorization code from sign-in. Supabase "does not support Server-to-Server notification endpoints", so handling revocation made on appleid.apple.com is not automatic. [Vendor: Supabase, https://supabase.com/docs/guides/auth/social-login/auth-apple] Flag: capture Apple's `authorizationCode` at sign-in and exchange it server-side; whether supabase-swift's `signInWithIdToken` path exposes a revocable token is [Unverified].
  5. Reports and blocks: reports filed **about** a deleted user are legal-hold candidates; decide retention. Tell the user in the deletion screen. [Inference]
  6. Show "We'll finish within N days" and send a confirmation. Immediate hard delete is simpler for v0. [Inference]
- Add UI test: delete account returns to entry and signs out.
- Local Debug/Staging deletion must be tested against local Supabase before Production.

### 3.4 Age 18+ gate

- App Store rule: if your terms impose a minimum age above the calculated rating you must override. [Apple] https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/ ("If your app has a EULA with minimum age requirements that exceed the rating that Apple calculated, you must override to a rating that adheres to the requirements.") -> set the App Store age rating to **18+**.
- Age rating tiers now: 4+, 9+, 13+, 16+, 18+. UGC, messaging/chat and age assurance are questionnaire items; social-feed amplification triggers 13+; unrestricted web access triggers 16+. [Apple] https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions . The embedded players might count as "unrestricted web access" only if users can navigate anywhere; keep the WebView locked to an allowlist and answer "No". [Inference]
- Apple does not prescribe an in-app gate format in the guidelines I read. [Apple, absence in fetched text of 2026-10-25]
- Declared Age Range API (`AgeRangeService`) lets an app ask for an age range; system may override your age gates by local regulation; requires a capability/entitlement. [Apple] https://developer.apple.com/documentation/declaredagerange . Apple's metadata lists `AgeRangeService` as iOS 26.0+, so it is unavailable on the iOS 17 floor; optional, do not depend on it for v0.
- Figma copy, `1480:4256`: "ARE YOU OLDER THAN 18?" with checkbox "By checking in I confirm that I am 18 years old or more." ([[2026-10-25-figma-full-walkthrough]]). Issues: "older than 18" excludes 18-year-olds; "checking in" is event wording; a pre-ticked/leading checkbox is easy to lie to but is common.
- Recommended wording [Inference]:
  - Screen title: "Confirm your age"
  - Body: "Kizuki is for people aged 18 and over."
  - Control: date-of-birth picker (neutral, no pre-selected qualifying date) or, for simplest v0, a checkbox "I am 18 or older." plus link "Terms of Use" and "Privacy Policy".
  - Under-18 result: "Sorry, you can't use Kizuki yet. You must be 18 or older." No account is created; store a local Keychain flag to stop immediate retry.
  - Footnote: "We use this only to keep the community safe. It isn't shown on your profile."
- Store a boolean and timestamp (`age_confirmed_at`, `terms_version`), not the birth date. Minimises data per 5.1.1(iii). [Inference]
- Self-declaration is not verification. If the user wants real age assurance, that is a separate vendor decision. [Inference]
- The gate must come before any profile data is stored for a minor; with Sign in with Apple the account exists after step one, so create the server profile row only after the gate passes. [Inference]

## 4. UGC: Guideline 1.2 and what "report + block" must include

### 4.1 The rule

Guideline 1.2: apps with UGC "must include: A method for filtering objectionable material from being posted to the app; A mechanism to report offensive content and timely responses to concerns; The ability to block abusive users from the service; Published contact information so users can easily reach you." Also: it is "your responsibility to remove content that violates this guideline, your terms of service, or your community standards"; failure may be a Developer Code of Conduct violation. [Apple] https://developer.apple.com/app-store/review/guidelines/ (1.2) . 1.5 adds that the app and its Support URL must include an easy way to contact you. Same URL.

Kizuki's UGC surfaces: handles and display names, bios, profile photos, cover images, collab photos (Search grid), project titles/descriptions/images, request messages, chat messages, profile links and embeds, taste favourites (free-text risk if custom entries allowed). Decision #25 removes comments, #24 removes follows: good, smaller surface.

### 4.2 Minimum set that should pass review

| Requirement | Concrete v0 implementation |
| --- | --- |
| Terms with objectionable-content rule | Terms of Use + Community Guidelines accepted at sign-up (link on the age-gate screen), stating that objectionable content and abusive behaviour are not tolerated and accounts may be removed. Apple's current guidelines text I fetched does not use the phrase "EULA"; the zero-tolerance wording is long-standing reviewer practice. [Unverified as a current written rule; recommended anyway] |
| Pre-post filtering | Server-side text check on handles, names, bios, project text, requests, messages: profanity/slur blocklist + length + URL rules, enforced in a Postgres trigger or Edge Function, not only in the client. Images: v0 needs at least (a) JPEG/PNG/HEIC only, size cap, (b) a moderation step before public visibility, e.g. new uploads visible to others only after an automated moderation API check passes, or held for review. The on-device `SensitiveContentAnalysis` framework only works if the user has turned on Sensitive Content Warning or Communication Safety (`analysisPolicy` != `.disabled`), so it cannot be the filter. [Apple] https://developer.apple.com/documentation/sensitivecontentanalysis/scsensitivityanalyzer/analysispolicy . Pick a moderation API in a later lane; vendor not researched here. |
| Report | "Report" action on every UGC surface: other-user profile, project, collab photo (post viewer), conversation/message, and each embed. Menu "..." -> Report -> reason list (Spam, Harassment or hate, Nudity or sexual content, Violence or threats, Scam or impersonation, Underage user, Intellectual property, Other) + optional text -> confirmation "Thanks. We review reports within 24 hours." -> content hidden for the reporter immediately. Writes a `reports` row (reporter_id, target_type, target_id, reason, details, status, created_at). The "24 hours" number is a commitment you choose; Apple only says "timely". [Apple, 1.2] |
| Timely response | Reports reviewed in Supabase dashboard (decision #16). Define a daily review owner and an SLA you can keep. Add content takedown + user suspension procedure. Appeals are out of v0 (decision #16). |
| Block | "Block" on profile and in chat. Effects: blocked user vanishes from my Home, Search, People-you-might-like, matches and requests; cannot view my profile or projects, send me requests or messages; existing conversation is closed to both; persists server-side with RLS enforcing it (not a client filter). Blocked list in Settings with Unblock. Blocking is silent to the blocked user. |
| Report + block together | After reporting, offer "Also block this user" in the same confirmation. |
| Auto-escalation | Hide content automatically after N reports from distinct users until reviewed. [Inference] |
| Contact info | Support email/URL in Settings > Help and in App Store Connect Support URL; Privacy policy URL; both must be live before review. [Apple 1.5, 5.1.1(i)] |
| Reviewer demo | Seeded mock data should include a reportable item and a blockable user so the reviewer can see both flows work. Describe both in App Review notes. [Inference] |
| Safety UX | Chat opens only after accepted request (decision #11). Add "Report" and "Block" in chat header; add one-time safety tips on first chat. [Inference] |

### 4.3 Things that commonly trigger a 1.2 rejection
[Inference from the rule text; no Apple statistics found]
- Report button exists but only on profiles, not on messages or images.
- Block only hides locally, not server-side.
- No visible contact information.
- No evidence of filtering; test accounts can post slurs.
- Anonymous or random chat features. Kizuki has none; do not add any "random match" feature. 1.2 lists "Chatroulette-style experiences, random or anonymous chat" as removable.
- Suki mascot "AI assistant" copy in Figma settings ("Suki's AI assistant settings"): 1.2 says UGC rules include AI content creation apps, and 5.1.2(i) requires disclosure and consent for sharing data with third-party AI. Do not ship it in v0. [Apple] guidelines URL above

## 5. Embeds and profile widgets

Decision #23: links + embedded players (YouTube, SoundCloud, Bandcamp, Letterboxd link; Instagram only if feasible without blocking review).

### 5.1 Cross-cutting rules (Apple)

- 2.5.6: apps that browse the web "must use the appropriate WebKit framework and WebKit JavaScript." `WKWebView` is the right container. [Apple] https://developer.apple.com/app-store/review/guidelines/
- 5.2.2: if the app "displays content from a third-party service, ensure that you are specifically permitted to do so under the service's terms of use. Authorization must be provided upon request." Keep the per-vendor evidence below in the repo for review. [Apple] same URL.
- 5.2.3: no features to save, convert or download media from YouTube, SoundCloud etc. without authorisation. Streaming-only embeds are the safe pattern. [Apple] same URL.
- 5.1.1(vii): if `SFSafariViewController` is used it must be visibly presented, not hidden. [Apple] same URL. Use it for "Open in ..." link-outs.
- Age rating: "Unrestricted Web Access" (any page in-app) moves the rating to 16+. A locked-down allowlisted embed view is not unrestricted browsing; answer the questionnaire accordingly and keep the allowlist real. [Apple, definition] https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions
- UGC: every embed is user-supplied content, so it needs a Report action and must disappear when the owner is blocked (section 4).

Design pattern for all players [Inference]:
1. User pastes a URL in profile edit. Client + server parse it against a **strict host allowlist** (`youtube.com`, `youtu.be`, `soundcloud.com`, `bandcamp.com` and `*.bandcamp.com`, `letterboxd.com`, optionally `instagram.com`). Store the canonical URL and a provider enum, never raw HTML.
2. Render a native "facade" card (provider icon, title, thumbnail if available, "Play" affordance). **No third-party request is made until the viewer taps.** This keeps profile scroll fast, avoids loading several `WKWebView`s, limits tracking exposure, and avoids autoplay rules.
3. On tap, present the player in a `WKWebView` with: `WKWebsiteDataStore.nonPersistent()`, `allowsInlineMediaPlayback = true`, `mediaTypesRequiringUserActionForPlayback = .all`, `decidePolicyFor navigationAction` that cancels anything off the provider's player host and routes link taps to `SFSafariViewController`.
4. Always show "Open in YouTube/SoundCloud/..." and "Report".
5. Disclose third-party embeds in the privacy policy and terms (YouTube requires this, see below).

### 5.2 Summary table

| Provider | Native-app WebView allowed? | API key / app review | Main terms limits | v0 verdict |
| --- | --- | --- | --- | --- |
| YouTube | Yes, documented: embedded player in `WKWebView` or `SFSafariViewController` | No key to embed. Referer / app ID required. | Must send Referer = `https://<bundle id>`; min 200x200 viewport; no overlays; no download/cache; link YouTube ToS and Google Privacy Policy in your own terms/privacy | **Build**, facade + WKWebView |
| SoundCloud | Yes, standard iframe widget in a WebView | No key for the Widget. API key only for API calls. | Attribution + permalink backlink; no caching of content; commercial-use limits in API Terms | **Build**, facade + widget |
| Bandcamp | Yes, iframe player | No key. Player needs numeric album/track id from Bandcamp's own embed code. No documented oEmbed or API. | No embed terms found; avoid scraping page HTML for ids | **Build with caveat**: accept only Bandcamp's official embed src; else link-out |
| Instagram | Yes, oEmbed HTML + `embed.js` in a WebView | As of 2026-06-15 Meta says no token and no App Review for oEmbed. | Public posts/profiles only; do not persist/extract oEmbed data; rate limits unclear for tokenless | **Defer to v0.1**, link-out chip in v0 |
| Letterboxd | Link only | API by request, excludes recommendation projects | n/a | **Link-out only** |

### 5.3 YouTube

- Embedding the player needs no API key; the YouTube IFrame Player API reference documents `onError` code 153: "The request does not include the HTTP Referer header or equivalent API Client identification." [Vendor: Google] https://developers.google.com/youtube/iframe_api_reference
- Required Minimum Functionality: [Vendor: Google] https://developers.google.com/youtube/terms/required-minimum-functionality
  - API clients that use the embedded player "must provide identification through the HTTP Referer request header."
  - In WebViews the Referer is empty by default. For iOS: `loadHTMLString:baseURL:` with `baseURL`, or `loadRequest:` with a `Referer` header. Format: HTTPS URL whose domain is the **bundle ID** on Apple platforms, e.g. `https://club.kizuki.ios`.
  - Use `WKWebView` or `SFSafariViewController`. `SFSafariViewController` cannot set Referer; set the `origin` player parameter instead.
  - Viewport at least 200x200; recommended 480x270 for 16:9.
  - No overlays or frames in front of any part of the player or its controls.
  - Autoplay only when more than half visible; only one autoplaying player per screen. (Kizuki: no autoplay.)
  - "Failure to comply... might result in reduced functionality in the YouTube embedded player."
- Developer Policies, section III.A: API clients "must display a link to YouTube's Terms of Service (https://www.youtube.com/t/terms), and they must also state in their own terms of use that, by using those API Clients, users are agreeing to be bound by the YouTube Terms of Service." Also a privacy policy that links the Google Privacy Policy. Policies forbid caching or storing "copies of YouTube audiovisual content". [Vendor: Google] https://developers.google.com/youtube/terms/developer-policies . Whether a bare embed counts as an "API Client" is not stated outright; the Required Minimum Functionality page treats embedded-player integrators as API clients, so comply. [Inference]
- Debug vs release bundle ids differ (`club.kizuki.ios.local`). Make the Referer value a build setting and test with the release id on a device build; the Debug id may still work because the only requirement stated is the app-ID format. [Inference]
- Error 101/150 (owner disabled embedding) must be handled with an "Open in YouTube" fallback. [Vendor: Google, same IFrame reference]
- Metadata for the facade: YouTube oEmbed (`https://www.youtube.com/oembed?url=...&format=json`) needs no key. Its terms are the YouTube ToS. Existence and ToS coverage from memory. [Unverified]

### 5.4 SoundCloud

- Widget: iframe `https://w.soundcloud.com/player/?url=<sound URL>&<params>` with optional `https://w.soundcloud.com/player/api.js`; parameters include `auto_play`, `show_artwork`, `buying`, `sharing`, `download`. [Vendor: SoundCloud] https://developers.soundcloud.com/docs/api/html5-widget
  - Set `download=false`, `buying=false` (v0 has no commerce), `auto_play=false`.
  - The doc example uses `api.soundcloud.com/tracks/<id>` URLs. Whether a public `soundcloud.com/...` permalink works as the `url` value is widely used but not stated on that page. [Unverified]
- API Terms of Use: [Vendor: SoundCloud] https://developers.soundcloud.com/docs/api/terms-of-use
  - Attribution: credit the uploader and SoundCloud, with "clearly visible backlinks... to the URL for the relevant sound on soundcloud.com (permalink_url)."
  - Caching: "Your app must not include file-save functionality, or otherwise designed to cache, download or persistently store any User Content." Session caching only.
  - Commercial: acceptable uses are narrow; unacceptable includes "any app that features any advertising, sponsorship or promotion around User Content or enables User Content (other than a user's own User Content)... to be embedded into the third party commercial services." A creator embedding their own sound on their own profile fits the "user's own" carve-out; **moderation must check the SoundCloud account matches the poster or accept the ambiguity**. Linking someone else's track is the grey area. [Inference]
  - AI: no use of SoundCloud content "for the purposes of informing, training, developing" AI. Do not feed embed metadata into the recommender.
  - Do not name the app with "SoundCloud"; use only supplied logo assets unaltered.
  - Whether these API terms govern the no-key Widget is not stated on the widget page; treat them as applying. [Inference]

### 5.5 Bandcamp

- Bandcamp Help Center: embedding is done from the album page: "click the Share/Embed control located just beneath an album's cover art, then click 'embed this album'", with options for size, colour, tracklist. [Vendor: Bandcamp] https://get.bandcamp.help/hc/en-us/articles/23020711574423-How-do-I-embed-a-Bandcamp-player-on-my-site
- No developer docs, API key or documented oEmbed were found. A WordPress plugin reports using `bandcamp.com/api/oembed` and falling back to scraping meta tags; a single probe of that endpoint on 2026-10-25 returned `{"error":true,"error_message":"bad version"}`, so it exists but is undocumented. [Unverified third-party / own probe]
- I found no embedding clause in Bandcamp's Terms of Use text fetched (`https://bandcamp.com/terms_of_use`). Absence of a clause is not permission. [Unverified]
- Recommendation: let the user paste either the plain page URL (rendered as a link card) or Bandcamp's **own embed code**; extract only the `src` and require it to match `^https://bandcamp\.com/EmbeddedPlayer/`. Never fetch Bandcamp pages server-side to find IDs. The `EmbeddedPlayer` path shape is from memory. [Unverified]

### 5.6 Instagram

- Instagram oEmbed (`GET graph.facebook.com/{version}/instagram_oembed?url=...`) returns blockquote HTML that loads `https://www.instagram.com/embed.js`. Accepts `/p/`, `/reel/` and **profile** URLs. [Vendor: Meta] https://developers.facebook.com/docs/instagram-platform/oembed
  - Limits: public posts only; private, inactive, age-restricted accounts and accounts with Embeds disabled unsupported; no Stories.
  - "Using metadata and page, post, or video content (or their derivations) from the endpoint for any purpose other than providing a front-end view... is strictly prohibited... including... persisting the metadata." So fetch at view time; do not store HTML or thumbnails; do not feed the recommender.
  - Rate limit stated: 1,000 requests per hour (token-based).
- App Review: the feature page says Meta oEmbed Read "requires App Review", business verification, possibly extra contracts. [Vendor: Meta, page dated 2025-04-08] https://developers.facebook.com/docs/features-reference/oembed-read
  - Newer: a Meta blog post of **2026-06-15** says oEmbed endpoints (Instagram, Facebook, Threads) "can be called without an access token. App Review for will no longer be required to embed public Meta content", and "Rate limits may differ. Token-based access through App Review may offer higher rate limits." [Vendor: Meta] https://developers.facebook.com/blog/post/2026/06/15/tokenless-access-to-meta-oembed-apis/
  - The older docs still describe the token + review path. The blog is newer and wins, but confirm in the live docs before shipping. [Verify]
- Feasibility verdict: technically feasible without Meta app review. Reasons to defer: (1) unknown tokenless rate limit when many profiles load; (2) `embed.js` pulls Instagram's UI and tracking into a WebView, adding privacy-label and review surface; (3) Meta Platform Terms still apply; (4) the Figma profile only shows an icon row of external links (Behance, TikTok, Instagram, Twitch, YouTube), not an embedded feed ([[2026-10-25-figma-full-walkthrough]]). Recommend: v0 = Instagram **link-out chip**; v0.1 = optional embed of one post or profile behind the same facade + allowlist pattern.

### 5.7 Letterboxd

- API access is "by request only"; "we are not granting access for data-analysis, visualization or recommendation projects, for LLM or GPT-related use, for private or personal projects"; RSS feeds exist for diary entries, reviews and lists; for movie data they recommend TMDB. [Vendor: Letterboxd] https://letterboxd.com/api-beta/
- No official embed widget was found. Decision: **link-out only** to `letterboxd.com/<username>/` shown as a profile link chip. No scraping, no RSS ingestion into recommendations (RSS rights are not stated; treat as not permitted for matching). [Inference]
- Do not use the Letterboxd logo until brand guidelines are checked. [Unverified]

### 5.8 Widget data model (suggested)

`profile_links(id, profile_id, provider, canonical_url, display_title?, created_at)` with a Postgres CHECK on provider and a trigger validating host against the allowlist, so a malicious client cannot insert arbitrary URLs. Rendering code trusts only `provider` + parsed id. [Inference]

## 6. Taste data: TMDB, MusicBrainz, Cover Art Archive

Decision #21/#22: taste cards with placeholder images, plus an in-app favourites picker (films via TMDB, music via MusicBrainz).

### 6.1 TMDB

- **Commercial use is not free.** The API Terms say the licence "does not permit any commercial use"; commercial use "is only permitted under a separate written agreement." [Vendor: TMDB] https://www.themoviedb.org/api-terms-of-use
  - FAQ: "Your project is considered commercial if the primary purpose is to create revenue for the benefit of the owner." Non-commercial use is free with attribution; commercial needs a licence via sales. [Vendor: TMDB] https://developer.themoviedb.org/docs/faq
  - Kizuki v0 has no payments (decision #12) but is a company product. Whether it is "commercial" is TMDB's call; ask TMDB before public launch. TestFlight with mock data is low risk. [Inference]
- **Attribution:** use the TMDB logo, with the notice "This product uses the TMDB API but is not endorsed or certified by TMDB", logo less prominent than the app's own marks, in an About/Credits section. [Vendor: TMDB, FAQ + terms above]
- **Caching:** must not "Cache, for longer than 6 months, any information obtained through or from TMDB". On termination purge TMDB content. [Vendor: TMDB, terms]. Implication: if favourites store title/year/poster path in Postgres, refresh them at least every 6 months, or store only `tmdb_id` and resolve at display time.
- No derivative works; no sublicensing; no ML/AI training on TMDB content (the terms bar using it "in connection with, including for training, a machine learning" system). **Do not feed TMDB metadata (genres, keywords) into a learned recommender.** Rule-based match reasons that show "you both like Paris, Texas" are display, not training. [Vendor: TMDB; interpretation mine]
- Rate limit: "somewhere in the 40 requests per second range"; respect 429. [Vendor: TMDB] https://developer.themoviedb.org/docs/rate-limiting
- Auth: Bearer "API Read Access Token" or `api_key`. [Vendor: TMDB] https://developer.themoviedb.org/docs/authentication-application . **Either secret in the app binary is extractable.** Put the key in a Supabase Edge Function proxy (`/tmdb/search`, `/tmdb/movie/{id}`) with caching and per-user throttling. [Inference]
- Images: base URL and sizes come from `/configuration`; example URL host `image.tmdb.org/t/p/`. Hotlink from TMDB's CDN; do not copy posters into Supabase Storage. [Vendor: TMDB image-basics; hotlink/no-rehost advice is mine because terms ban "image hosting service" use and long caching]
- Fit: good data for a film picker: search by title, year, poster, id. Needs attribution UI, a legal check, and the key proxy.

### 6.2 MusicBrainz

- **Data licence:** core data (artists, release groups, releases, recordings, labels, areas...) is **CC0**; supplementary data (user annotations, tags incl. genre associations, ratings, search indexes, edit history) is **CC BY-NC-SA 3.0**. [Vendor: MetaBrainz] https://musicbrainz.org/doc/About/Data_License and https://musicbrainz.org/doc/MusicBrainz_Database
  - Picker needs names and IDs only: core data, no licence obstacle. **Do not use `inc=tags/genres/ratings`** for ranking or display without a licence plan.
- **Service terms (separate from data licence):** "Non-commercial use of this web service is free; please see our commercial plans or contact us if you would like to use this service commercially." No API key. "you must have a meaningful user-agent string." [Vendor: MusicBrainz] https://musicbrainz.org/doc/MusicBrainz_API . "All of our data is available for commercial licensing." https://musicbrainz.org/doc/MusicBrainz_Database
  - Same commercial-status question as TMDB; definition of "commercial" for MetaBrainz was not found on the pages read. [Unverified]
- **Rate limit:** "never make more than ONE call per second"; IPs exceeding it get 503; rate measured per source IP "(on average) 1 request per second"; User-Agent format `Application name/<version> ( contact-url or contact-email )`; anonymous UAs are throttled harder. [Vendor: MusicBrainz] https://musicbrainz.org/doc/MusicBrainz_API/Rate_Limiting
  - Direct from devices, each device has its own IP, so a client-side serial queue at >= 1.1 s spacing + typeahead debounce (e.g. 600 ms, min 3 chars) is enough.
  - If routed through one Edge Function, all users share server IPs and the 1 rps cap becomes global: it needs a shared queue + cache. Use direct-from-device for MusicBrainz in v0, proxy for TMDB. [Inference]
  - UA example: `Kizuki/0.1.0 (support@<domain>)` once the contact address exists.
- Endpoints for the picker: `/ws/2/release-group?query=...&fmt=json` (albums), `/ws/2/artist?query=...&fmt=json`. Search is the only request that works without an MBID. [Vendor: MusicBrainz, API page]

### 6.3 Cover Art Archive

- `/release-group/{mbid}/front-250|500|1200` returns a 307 redirect to the community-chosen front image, 404 if none; `/release/{mbid}/front` likewise. "There are currently no rate limiting rules in place" (some endpoints still list 503 for exceeded limits). [Vendor: MusicBrainz] https://musicbrainz.org/doc/Cover_Art_Archive/API
- Rights: images are "collected for archival purposes... Use the images at your own risk. ... Be respectful of the rights of the artists and labels." No licence is granted. [Vendor: MusicBrainz] https://musicbrainz.org/doc/Cover_Art_Archive
- Risk: showing album covers in a commercial app is a copyright grey area, same as every music app that does not hold label licences. Mitigation: hotlink (do not re-host), small thumbnails, takedown process, and a text-only fallback tile. Many album covers 404; design a letter-tile fallback. [Inference]
- Redirects go to archive.org; configure `URLSession` to follow 307 and cache the final image. [Inference]

### 6.4 Fit verdict for the favourites picker

| Need | TMDB | MusicBrainz + CAA |
| --- | --- | --- |
| Search quality / IDs | Good | Good (fuzzy, needs disambiguation text) |
| Images | Good posters | Patchy, rights grey |
| Free for TestFlight prototype | Yes (non-commercial) | Yes |
| Free at public launch | Needs written agreement if commercial | Needs commercial plan if commercial |
| Secret key issue | Yes, proxy needed | No key |
| Rate-limit shape | ~40 rps | 1 rps per IP |
| ML/recsys training | Prohibited | CC0 core fine; tags are NC-SA |

Alternatives if licences are a blocker (not researched in depth): Wikidata structured data is CC0 with no attribution requirement [Vendor: Wikimedia] https://www.wikidata.org/wiki/Wikidata:Licensing, but its image rights differ and its search is weaker. The iTunes Search API covers movies and music but its terms are old (page dated 2017) and promo-content rules apply. [Vendor: Apple, archive page] https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/index.html . Both [Unverified for this use].

Data minimisation: store `source` (`tmdb|musicbrainz`), `external_id`, `title`, `year`, and refresh date; not raw JSON.

## 7. Placeholder images (taste cards and mock collab photos)

Needs: taste-card placeholder images (decision #21), 3-column grid of mock "collab photos" (decision #18/#19), project cover images. Avatars are covered by Blobatar.

Recommendation: **Unsplash**, photos downloaded by hand (no API) and bundled/seeded.

| Source | Licence summary | Fit |
| --- | --- | --- |
| Unsplash | Free for "commercial and non-commercial purposes", "No permission needed (though attribution is appreciated!)". Longform: "irrevocable, nonexclusive, worldwide copyright license" to download, copy, modify, distribute. Not allowed: selling images without significant modification; "Compiling images from Unsplash to replicate a similar or competing service." [Vendor: Unsplash] https://unsplash.com/license | Explicit distribution grant; large creative catalogue. |
| Pexels | "All photos and videos on Pexels are free to use." Credit not required. Prohibited: identifiable people "in a bad light"; selling unaltered copies; implying endorsement; redistributing on other stock/wallpaper platforms; using as trademark. [Vendor: Pexels] https://www.pexels.com/license/ | Also fine. Explicit bundling language absent. Includes video. |

Caveats:
1. **Use the downloaded files, not the Unsplash API.** The API has extra rules: hotlinking required, attribution with photographer link at every display, download-tracking pings, quota. [Vendor: Unsplash] https://unsplash.com/api-terms . Those rules do not apply to licence-only use. [Inference]
2. License covers copyright only. The Unsplash licence page says nothing about model releases, property releases or trademarks; the page tells you to check the photo or FAQ. Avoid identifiable faces, logos, branded products, artworks that are themselves copyrighted (gallery walls, album covers, posters), and readable text. Prefer hands, instruments, desks, textures, abstract set photos. [Vendor: Unsplash + inference]
3. Mock users with real people's faces implies those people use Kizuki. Use Blobatar avatars for users, and no portrait photos in the seed. Pexels explicitly prohibits "imply endorsement... by people or brands." [Vendor: Pexels]
4. Do not ship these as final taste-card art: decision #21 already makes image rights, taxonomy and tagging owner launch-blockers. Keep placeholders in a clearly named `Placeholder/` asset catalog and a manifest. [Repo decision]
5. Keep a `docs/assets/placeholder-images.md` manifest: photo URL, photographer, date downloaded, licence page snapshot date, file hash. Add a Credits screen line "Placeholder photos from Unsplash". Attribution is optional, but cheap goodwill and audit trail. [Inference]
6. The Figma illustration zip (`docs/design/illustrations/`) is the user's own artwork and is not stock. Do not mix with Unsplash in the same asset set without labelling.
7. Size: seed ~40 images at 1080 px wide JPEG q80 (~150 KB) = ~6 MB if bundled; better to upload to Supabase Storage in the seed script so the app bundle stays small. [Inference]
8. Apple 5.2.1: only content "that you created or that you have a license to use." A saved licence snapshot is your evidence. [Apple] https://developer.apple.com/app-store/review/guidelines/

## 8. TestFlight path

### 8.1 Checklist

| # | Step | Source / note |
| --- | --- | --- |
| 1 | Apple Developer Program membership, USD 99 per year. Individual (legal name shows as seller) or Organization (legal entity, D-U-N-S number, public website on own domain, legal authority). | [Apple] https://developer.apple.com/programs/enroll/ . Seller name = personal name for individuals. Org enrolment is slower. Open question: which entity. |
| 2 | Account Holder signs latest agreements in App Store Connect Business section. | [Apple] https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app |
| 3 | Register App ID `club.kizuki.ios` with capabilities: Sign in with Apple; (later) Push Notifications, Associated Domains. Xcode "Automatic" signing can create it (`CODE_SIGN_STYLE: Automatic` already set). | [Repo] + [Inference] |
| 4 | Decide on `club.kizuki.ios.local` (Debug): register separately or avoid Apple capabilities in Debug. | [Repo] `Local.xcconfig` |
| 5 | Create app record: platform iOS, unique name, primary language, bundle ID, SKU, user access. Status "Prepare for Submission". | [Apple] add-a-new-app URL above. "Kizuki" name availability is [Unverified]. |
| 6 | Add `PrivacyInfo.xcprivacy` to the app target (and confirm SDKs). | Section 8.3 |
| 7 | Add `ITSAppUsesNonExemptEncryption = NO` to both Info.plists. | Section 8.2 |
| 8 | Add purpose strings, entitlements. | Section 2 |
| 9 | Set version `0.1.0` / build `1` (exist). Bump build for every upload. | [Repo] `project.yml` |
| 10 | Archive with scheme `Kizuki-Staging` or `Kizuki-Production`; `validate-release-config.sh` already blocks bad config. Upload via Xcode Organizer. | [Repo] |
| 11 | Fill App Privacy answers and Privacy Policy URL. Required for all apps; the page does not say whether external TestFlight needs them, but first App Review submission does. | [Apple] https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy |
| 12 | Internal testing: up to 100 App Store Connect users, no review. | [Apple] https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/ |
| 13 | External testing: up to 10,000 testers; first build of a group goes to Beta App Review; test info needed (beta app description required, feedback email); sign-in demo account if login required. | Same URL + [Apple] https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information |
| 14 | Builds expire after 90 days. | [Apple] testflight-overview |
| 15 | Support URL + contact email live (1.5, 1.2). | [Apple] guidelines |

Note: external TestFlight builds are reviewed against the App Review Guidelines; everything in sections 2-4 applies at Beta App Review, not only at store release. [Apple] "to check compliance with the App Review Guidelines", testflight-overview.

### 8.2 Export compliance

- Apps that use encryption are subject to US export rules; "Typically, the use of encryption that's built into the operating system — for example, when your app makes HTTPS connections using URLSession — is exempt from export documentation upload requirements, whereas the use of proprietary encryption is not." Set `ITSAppUsesNonExemptEncryption` to `NO` for exempt-only use. [Apple] https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations
- "If your app uses exempt forms of encryption, you might alternatively be required to submit a year-end self-classification report to the U.S. government." Same URL. Ask a lawyer or the entity's advisor; not legal advice.
- Kizuki uses HTTPS via URLSession (supabase-swift) and Keychain, no custom crypto. `CryptoKit.SHA256` is used for avatar hashing in `KizukiDesignSystem` and for the Apple sign-in nonce. Hashing is generally not an encryption item, but whether CryptoKit use changes the answer is [Unverified]. Add the key as `NO` only after confirming. [Repo + Inference]
- France: encryption import/export controlled for distribution in France; ANSSI. [Apple] https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance . Exclude France in availability if documentation is unclear. [Inference]

### 8.3 Privacy manifest (`PrivacyInfo.xcprivacy`)

- A privacy manifest records (1) data types collected and (2) "required reasons APIs" used; the file must be named `PrivacyInfo.xcprivacy` and added to the target's resources. [Apple] https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- "Starting May 1, 2024, apps that don't describe their use of required reason API in their privacy manifest file aren't accepted by App Store Connect." [Apple] https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api . Declared reasons must match actual use, and cannot be used for tracking.
- Required-reason categories (from memory; confirm with Xcode's "Generate Privacy Report" on the archive): UserDefaults / `@AppStorage` (reason `CA92.1`), file timestamp APIs, system boot time, disk space, active keyboard list. [Unverified in this session]
- Current repo state: no manifest. A scan of the pinned supabase-swift v2.55.4 git tree found **no** `PrivacyInfo.xcprivacy` and no `UserDefaults` use in `Sources/`. [Repo-cache check] The app's own code should also be searched for `UserDefaults`, `@AppStorage`, `.creationDate`, `systemUptime`.
- Declare collected data types (App Store privacy labels should agree) [Inference, confirm in App Store Connect]:
  - Email address, name (sign-in), user ID, coarse location (city), photos/videos (profile + collab uploads), other user content (bios, messages, project text), device ID/push token if remote push is added, crash/diagnostics only if an SDK is added.
  - Tracking: none, no ATT prompt. Do not add a third-party analytics SDK in v0.
- Third-party embeds load remote web content in `WKWebView`; those domains are not "tracking domains" for your manifest unless you share identifiers with them, which the facade pattern avoids. [Inference]

### 8.4 Review-note template (for the first Beta App Review)

Include: demo account credentials (non-expiring), statement that permissions are optional, where to find Report/Block/Delete account, support URL, note that the backend is live and seeded, statement that content is mock/fictional, third-party content list (YouTube, SoundCloud, Bandcamp embeds with TOS links). Notes field limit is 4000 bytes. [Apple] https://developer.apple.com/help/app-store-connect/reference/app-review-information (fields: Contact, Sign-in required, Notes)

## 9. Risks and open questions

### 9.1 Risks, ranked

| # | Risk | Likelihood / impact | Mitigation |
| --- | --- | --- | --- |
| 1 | **No reachable backend for TestFlight.** Decisions #1, #10, #18 conflict: TestFlight cannot reach local Supabase; production is off-limits for mock data; `AppConfiguration` forbids cross-environment URLs. | Certain / blocks round goal | Create a cloud staging Supabase project seeded with mock data (section 1.8), or ship a Demo build on fixtures. User decision needed first. |
| 2 | **Guideline 1.2 gaps at Beta App Review.** No image moderation, report only on some surfaces, block client-side only, no staffed report review. | High / rejection | Section 4.2 table is the minimum; add reportable seed item for the reviewer; assign a human reviewer for reports. |
| 3 | **Third-party licence terms are non-commercial by default.** TMDB: commercial use needs a written agreement. MusicBrainz: non-commercial service use is free, commercial plans otherwise. SoundCloud API terms restrict third-party commercial embeds. Cover Art Archive images carry no licence. | Medium / public-launch blocker, not TestFlight blocker | Decide commercial status; contact TMDB and MetaBrainz before public launch; keep picker behind a thin `TasteCatalogRepository` so a source can be swapped. |
| 4 | **Up-front permissions drawing a rejection or a bad grant rate.** Figma has "Allow" / "Maybe later" buttons that break Apple's pre-alert rules; denial paths must not block. | Medium / rework | Section 2.3 design; XCUITest denial paths; provisional notifications as fallback. |
| 5 | **Account deletion incomplete for Sign in with Apple.** Supabase says it does not support server-to-server notification endpoints; Apple requires token revocation. | Medium / rejection (5.1.1(v)) | Edge Function that deletes data, revokes Apple token, then deletes auth user; test on a physical device with a real Apple ID. |
| 6 | **Email sign-in unusable by App Review** if magic-link/OTP only. | Medium / rejection (2.1) | Provide password demo account or password sign-in. |
| 7 | **Age-gate wording and rating.** Figma says "older than 18"; Apple requires rating override to 18+ when your terms require 18. | Medium / rejection or mismatch | Section 3.4 wording; set rating to 18+. |
| 8 | **YouTube embed error 153** in WKWebView when Referer is missing; **SoundCloud/Bandcamp terms ambiguity**. | Medium / broken widgets | Referer = `https://<bundle id>`; facade + fallback link; legal check on SoundCloud "own content" rule. |
| 9 | **Design tokens unverified** (Figma quota); `.preferredColorScheme(.dark)` in foundation may fight the pale feed screens; custom centre tab icon may not match the system bar. | Medium / rework | Wait for Figma Dev seat (decision #27) before building the design system beyond tokens. |
| 10 | **Apple Developer account entity unknown.** Organisation enrolment needs D-U-N-S and a public website on the org domain; seller name = legal name of the individual or entity. | Unknown / schedule | Ask the user now; start enrolment early. |
| 11 | **Export-compliance and privacy-manifest omissions** stop the upload or add friction. | Low / easy fix | Add keys and manifest before first archive. |
| 12 | **MusicBrainz 1 rps** with many users behind one proxy IP would 503. | Low in v0 | Direct-from-device calls with client throttle. |
| 13 | **Instagram embed** adds Meta terms, tracking surface, unknown tokenless limits. | Low if deferred | Link-out in v0. |

### 9.2 Open questions for the user

1. **Backend for TestFlight:** cloud staging Supabase seeded with mock data (recommended), Demo build on bundled fixtures, or something else?
2. **Apple Developer account:** individual or organisation? Who is the Account Holder? Is a D-U-N-S number available?
3. **Domain and contact:** which domain hosts privacy policy, terms, support page and (later) Universal Links? Which support email goes in MusicBrainz User-Agent, App Store Connect and the app?
4. **Commercial status:** may I treat Kizuki as commercial for TMDB/MusicBrainz purposes and plan outreach before public launch? Or is the first public release non-commercial?
5. **Email sign-in style:** password, 6-digit code, or both? Password gives App Review a clean demo account.
6. **Pre-permission screens:** accept a single "Continue" button on both (no "Maybe later")? Accept `.provisional` notifications if explicit opt-in is poor?
7. **Age gate:** checkbox "I am 18 or older" or date-of-birth picker? Accept an 18+ App Store rating?
8. **Moderation staffing:** who reviews reports daily in the Supabase dashboard, and what response time will you promise? Budget for an image-moderation API?
9. **Tab bar:** system `TabView` with icon-only items (recommended), or pixel-match custom bar with the larger Suki button?
10. **Push:** local notifications only in v0, or build the APNs sender (key, Edge Function)?
11. **Instagram:** link-out only in v0 (recommended) or embed?
12. **Suki AI assistant** (Figma settings copy): confirm it is out of v0.
13. **Cover art:** accept Cover Art Archive hotlinks (rights grey area) or text-only tiles for music at launch?
14. **Report retention:** when a user deletes their account, keep reports filed against them for how long?
15. **App name:** "Kizuki" availability in App Store Connect has not been checked.

## 10. One-page recommendation

### Build (new work, in this order)

1. `KizukiTestSupport` fixtures + `Dependencies` struct + `AppRoute`/`AppRouter` in Core. Everything else depends on them.
2. App shell: 5-tab `TabView` with per-tab `NavigationStack`, system tab bar, deep-link entry (`kizuki://`, notification tap).
3. Entry flow: Sign in with Apple (native + nonce), email sign-in, 18+ gate, Terms/Privacy links, then onboarding steps.
4. Permission primers for location (Continue only, manual city fallback) and notifications; Settings status row.
5. Safety kit: Report sheet, Block, blocked list, server-side RLS enforcement, `reports` table, auto-hide after N reports, support contact, Delete account Edge Function (data purge + Apple token revoke).
6. Feature modules per tab (Home, Search, Suki, My Projects, Profile) + Inbox; chat only after accepted request, enforced in RLS.
7. Embed module: allowlist parser, facade card, `WKWebView` player for YouTube (Referer), SoundCloud, Bandcamp (official embed src only); link chips for Instagram, Letterboxd, others.
8. Taste picker: `TasteCatalogRepository`; TMDB via Edge Function proxy with cache; MusicBrainz direct with 1 rps client queue and proper User-Agent; CAA hotlinked front-250 with letter-tile fallback; TMDB attribution in Credits.
9. Release plumbing: `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption`, purpose strings, entitlements, App Store Connect record, privacy labels, review notes, demo account, age rating 18+.
10. Placeholder photo set from Unsplash with manifest and credits.

### Reuse (keep as is, extend)

- `AppSession` generation-guarded session/profile state; `SessionRepository` / `ProfileRepository` pattern.
- `AppConfiguration` validation, the three xcconfig environments, `validate-release-config.sh`.
- `SupabaseBackend` (Keychain storage, PKCE, `.local` sign-out), supabase-swift pin and `Package.resolved`.
- `ProfileAvatar` + 32 bundled Blobatar PNGs (Blobatar licence file included).
- Swift Testing for logic, XCUITest launch-arg fixtures, pgTAP RLS tests, XcodeGen project generation.
- Observation (`@Observable`) as the only state mechanism.

### Skip (for v0)

- TCA/Redux or other architecture libraries; Combine-heavy patterns; SwiftData/offline queue; image-loading SDKs.
- Instagram embed (link chip only); Letterboxd API/RSS (link only); Spotify; any scraping.
- `Always` location, continuous location, geofencing.
- Remote push, unless a sender is funded; `.provisional` is the fallback.
- Declared Age Range API (iOS 26+ only); `SensitiveContentAnalysis` as the content filter.
- Google sign-in (decision #13); comments, follows (decisions #24/#25); payments UI (decision #12).
- Suki AI assistant; third-party analytics SDKs; ATT prompt.
- MusicBrainz tags/ratings/genres; re-hosting TMDB or Cover Art Archive images.
- Pixel-matched custom tab bar until the Figma Dev seat confirms exact tokens.

### Gates before the first external TestFlight build

- Backend decision (open question 1) closed and a seeded environment live.
- Privacy policy and support URLs live; terms mention YouTube ToS.
- Report, Block, Delete account demonstrably working with a demo account.
- Permissions: denial paths tested.
- Privacy manifest, export-compliance key, App Privacy answers entered.

### Gates before public App Store release

- TMDB and MetaBrainz commercial-status answers; SoundCloud terms legal check.
- Image rights, taxonomy and tagging owner (decision #21) resolved; placeholders replaced.
- Moderation staffing and response time operating.
- Re-verify Meta oEmbed and Apple guideline text on the release date; both change.

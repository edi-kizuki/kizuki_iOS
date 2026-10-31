# Header appearance experiment

Related: [[KizukiIcons]], [[Components]], [[SettingsViews]], [[Portfolio widget integration]].

## Current direction — October 28 follow-up

The user superseded the experiment after PRs #5 and #6 merged:

- The global Messages/inbox shortcut belongs only on Feed. Feed keeps its Kizuki logo and existing layout; it no longer has Settings.
- Settings is available only at the top right of the own Profile, through a three-line menu over the cover. Other people's profiles retain their separate report/block menu.
- Search, Suki and My Projects have no reserved header row. Their content starts at the safe area rather than below an empty header.
- Backgrounds, profile cover, work media and collab gallery extend to the horizontal screen edges. Crew, Requests, Create and My Projects cards now float inside those backgrounds as described below. Text, form controls and touch targets retain internal padding and system safe areas.
- The Minimal/Symbols preference is removed. Existing stored preference values are ignored.
- Contextual chat actions inside Crew and profile content are preserved; these are not the global inbox shortcut.

This applies to the Debug/local tab-root UI. Detail navigation and edit-form spacing are retained.

### Crew artwork and cards

The Your Crew header now uses the actual Medusa from Kizuki App (Copy) / Drawings / “WhatsApp Image 2026-10-12 at 15.59.18 1”, file `nPqXTMCtd3OVZTSU7Y2uN3`, node `1609:387`. `CrewMedusa.png` is cropped from the original 1280 × 896 source at `(1060, 395, 1250, 520)`. Its black background becomes transparency using luminance as alpha. The drawing is not redrawn or vector-traced. The 190 × 125 raster is rendered proportionally in an 88 × 58 point slot, in cream. The source resolution limits sharpness at 3× display scale. Other Suki empty-state artwork is unchanged.

Crew cards use larger avatars, the shared bold body type, the existing outlined profile button, a contextual chat button and an unframed overflow menu. Chat and overflow targets remain 44 × 44 points. Names and roles wrap with Dynamic Type. Profile, chat and remove-confirmation behavior is unchanged. The initial full-width, separated-row treatment at `1201929` is superseded by the floating-card direction below.

### Floating cards and Feed prompts — latest direction

The user asked for cards closer to Feed and the rounded, floating feel of iOS 26. Crew, incoming/sent Requests, Create choices, and all My Projects sections (Drafts, Published, Past) share a 20-point continuous corner radius, 12-point outer gutters, a subtle border and soft shadow. This is a shared opaque content surface, not a custom glass imitation. Backgrounds remain edge-to-edge. Feed project thumbnails also retain rounded card corners. Request actions stack when horizontal space is insufficient; project titles wrap rather than truncate.

The initial “Your next move” carousel and subsequent solid-blue banners are superseded by quiet inline notices. There is no section heading, counter, horizontal prompt carousel, category label, or separate CTA row. One banner appears before the recommendations; remaining applicable banners sit between/after feed sections. The notice uses Kizuki Blue (`#3F7BE2`) at 14% opacity over the existing Baby Blue feed background, charcoal 14-point regular text, a blue leading symbol and a small chevron. The default row is 44 points high, with no shadow or border. Supporting detail stays in the VoiceOver label. Text scales and wraps at accessibility sizes without a minimum text-size override. The four state-driven prompt types remain:
- Finish an owned draft: opens that project. Any collaborating user with a draft can resume it, regardless of their original start/join intent.
- Review incoming pending requests: opens Suki → Requests → Incoming and resets stale detail navigation.
- Finish profile basics: opens Edit profile and disappears once the existing completion rules are satisfied.
- Say hello to a Crew connection with an empty conversation: opens that chat and disappears after a message. Fixture request acceptance no longer inserts a fabricated message on the user's behalf.

Only applicable prompts appear. Blocked people and resolved requests are excluded. Inspiration-only users do not receive collaboration prompts. No unread status, freshness, deadlines or urgency is invented. These are Debug/local screens backed by repository state, not a live notification service.

### Flush profile cover — October 28 follow-up

The own-profile tab cover now extends across the full screen width and behind the status area. It is a separate full-width section rather than a child of the padded profile body. Its height remains 184 points, with the identity block overlapping the bottom by 24 points, bringing the profile higher on screen. Settings stays below the top safe-area inset with a 44-point target and a 20-point trailing inset. Body text retains readable gutters; work media and the collab gallery remain full-width. Other people's profiles retain their native navigation and report/block menu. The existing patterned cover is preserved; no uploaded-cover backend is implied.

At accessibility text sizes, the completion heading and count stack vertically so the count no longer forces the heading into broken words.

The exact subtler historical banner referenced by the user was not identified in committed source. This treatment follows the requested visual direction rather than claiming an exact restoration.

Verification: 89 unit tests, eight focused UI tests and ten release-configuration checks passed. UI coverage includes the full-width/top-edge profile scroll, raised identity, Settings target, largest accessibility text, Feed destinations, other-profile safety menu and completion-checklist save/hide behavior. Normal and accessibility screenshots were inspected on iPhone 17 Pro Latest. The first geometry-test attempts needed an accessible identity container and removal of an unavailable app-owned status-bar query; the final run passed. Staging validation was attempted but failed because the host disk filled while writing Xcode's build manifest. Temporary Staging build caches/products were removed to finish Debug validation. Staging was not revalidated, and no live backend or full UI-suite verification is claimed.

### Brand correction — October 28

The user reversed the `concept_8` logo change. The original Feed logo, `concept_8.6` wordmark/K mark, app-icon artwork and splash crest are restored. Feed retains the requested yellow `#EBAF41` body and original charcoal eye details. App-icon variants use cream/charcoal, palette orange/charcoal, and system-tinted monochrome. The new Feed DM icon is Figma's filled message circle (`nPqXTMCtd3OVZTSU7Y2uN3`, `1312:10726`), in Kizuki Orange `#E95833`. Its 44-point hit target, accessibility label and inbox destination are unchanged. Source and regeneration: [[README]] in `docs/design/icons/`.

Historical reversal verification: 89 unit tests, three focused UI tests (draft/request/profile destinations, accessibility-XL banners, Feed-only Messages and Profile-only Settings), ten configuration tests and Staging build/artifact inspection passed. Default and accessibility-XL screenshots were inspected. All app icons are opaque 1024-pixel squares. The former solid-blue, 19-point bold banner and its contrast measurement are superseded by the 14-point regular, tinted notice documented above. No live backend operations or full UI-suite run.

### Profile photos and editor cleanup — October 28

This supersedes the earlier note that the generated cover and avatar cannot be changed. In the Debug/local preview, Edit profile now offers Change profile picture and Change cover photo using Apple's system photo picker. Changes are previewed before Save. Cancel discards them. Remove profile picture restores the deterministic Blobatar; Remove cover photo restores the generated pattern. Both images save atomically with the rest of the local profile and survive relaunch in the normal persistent preview. Uploaded portraits render in shared avatar components across the app. Cover images stay flush to the screen edges; the preview uses the same centered fill as the profile.

This is local photo import, not cloud upload: the editor explicitly says photos stay on this device. The live OwnProfileRepository is still unavailable. Supabase Storage buckets, ownership policies, signed media access and live profile writes are not silently simulated or deployed by this change. Cloud persistence remains unfinished.

Only selected images are imported; the app does not request general photo-library access. File imports are capped at 25 MB and 100 megapixels, downsampled to at most 1600 pixels (cover) or 512 pixels (portrait), re-encoded as JPEG under 1 MB per image, and stripped of original GPS/EXIF metadata. Animated images are rejected. Normalized bytes are stored in the existing atomic local profile snapshot, avoiding orphaned media files on cancel/save failure. Optional model fields preserve old snapshots. Data validation and repository failures leave the previous profile intact.

The redundant Your profile basics heading and introductory paragraph are removed. Work and Your links become Portfolio. Photos remain optional and do not change profile completion rules or matching.

CI diagnosis: the historical iOS job for run `40762509022` at `528c53e` has zero steps and the annotation “The job was not acquired by Runner of type hosted even after multiple attempts”, alongside notices of macOS arm64 capacity constraints. This is a runner-acquisition failure, not a test failure. The newer run `40769335775` was observed executing its iOS tests. The workflow now selects `macos-15-intel`, whose documented image includes Xcode 26.0.1, to avoid the constrained arm64 pool. All tests, release guards, artifact checks and timeouts are retained. A successful final-revision GitHub run is still required; this workaround alone is not a CI-pass claim.

The newer run subsequently completed with a genuine test failure: `testEntryOnboardingAndEveryTab` still tapped Continue ten times after Favourites was removed. The ten-screen route has nine Continue buttons followed by Enter Kizuki. The test now asserts every numbered step, the single notification Continue action and the final Enter action before checking all tabs. No assertion is disabled. GitHub also reported no uploaded result bundle because upload-artifact excludes hidden paths by default; the artifact step now explicitly includes hidden files only within its existing `.build/*.xcresult` path.

Author validation: the complete local suite passed with 130 tests passed and two opt-in live-backend tests skipped (`/tmp/kizuki-photos-full-suite.xcresult`: 95 unit and 35 UI passes). This includes the corrected full onboarding route, actual system-picker photo selection, Save/Cancel/removal, all existing tabs and profile/link regressions. After that run, a top scrim was added only to custom covers so bright images do not wash out the white status bar; the final-code three-test run for photo selection, largest-text editing and flush cover geometry passed (`/tmp/kizuki-photo-final-cover.xcresult`). Ten release-configuration tests, two local guard tests, five screenshot guard scenarios and four runtime guard cases passed. Staging build/artifact inspection passed; the Release build was correctly refused by the production barrier. Normal and accessibility XXXL screenshots were inspected. Earlier new-test failures were selector issues (the Photos picker has identifier Photos, not its aggregated Cancel label; the editor and underlying profile both contain Portfolio), corrected before the passing runs. Test/gallery launches remain ephemeral; normal Debug launches persist the local profile. No cloud/backend photo upload or physical-device validation is claimed.

Author: Astra. Independent reviewer: Fable 5.1, pending. Related: [[README]], [[AGENTS]], [[ProfileView]], [[Models]], [[AppStore]], [[PrototypeStoreTests]].

### Profile availability battery, floating widgets and favourites removal — October 28

The user asked where the profile banner picture is changed, asked for the profile battery to represent weekly availability in green, yellow and red, asked the availability box and the Work widgets to follow the rest of the app’s design, and asked for the Favourites section to be removed altogether while taste capture is reconsidered.

- The profile cover remains the generated pattern from [[ProfileView]] (`coverAccent`), tinted per profile id. There is no cover-photo editing control and this change does not add an upload backend.
- The battery is no longer fixed at 75 percent. It reads the selected weekly availability from [[Models]]: Under 5 hours a week is Low (red, quarter battery), 5–9 hours is Medium (yellow, half battery), 10 or more hours is High (green, full battery). The glyph is hidden from VoiceOver; the text beside it always states the bucket, for example “Low availability · Under 5 hours / week”, so colour is never the only signal. Own profiles still show work mode and pay preference privately; other profiles show only the public availability; inspiration-only profiles show no availability panel.
- Red and green are new semantic tokens in `KizukiTheme` (`availabilityLow` `#FF453A`, `availabilityHigh` `#30D158`). They are the iOS dark-appearance system red and green values, chosen for the dark-only palette; they were not taken from the Kizuki Figma file. Medium reuses Kizuki Yellow `#EBAF41`.
- The middle bucket label changed from “5–10 hours / week” to “5–9 hours / week” so the three buckets do not overlap. Stored raw values are unchanged, so existing saved profiles decode as before; the new label is presentation only and applies to Edit profile, onboarding, the request composer, project creation and project detail. Fixture requests use the new label.
- The availability panel and each Work widget now use the shared floating card: 20-point continuous radius, 12-point outer gutters, the subtle border and shadow used by Crew, Requests, Create and My Projects. The widget media sits inside the rounded clip with no seam; the provider row keeps a 16-point inset and the external link keeps its 44-point target. Cover, overall background and the collab gallery stay full width. The `edgeToEdge` path for these two cards is gone.
- Favourites are removed as a user-facing feature: no profile section on own or other profiles, no onboarding picker step, no Settings privacy toggles, and no “Shared favourites” recommendation reason, so hidden legacy picks cannot shape suggestions. Onboarding is now 10 collaborator steps and 7 explorer steps; the `onb-favourites` screen id and gallery entry are gone. The existing taste-card step and its matching toggle are unchanged; no new taste questionnaire was added.
- Two widget details changed while checking Dynamic Type and targets: the widget title wraps to two lines instead of truncating at accessibility sizes, and the “Open on …” link now carries its 44-point minimum height on the tappable label itself (the previous frame sat outside the link, leaving a 21-point target).
- Compatibility: the legacy `favourites`, `showFavourites`, `useFavouritesForMatching` and `person.favourites` fields stay on the stored profile model so existing local profile files load and round-trip without data loss. Their defaults for new profiles are now off. No remote schema or data was changed. The historical onboarding screenshots under `hub/prototypes/` are left in place.

Availability/favourites verification (October 28, author Fable 5.1, awaiting independent Astra QA): 93 unit tests in 9 suites passed (`/tmp/kizuki-profile-availability-final.xcresult`), including new tests for the three availability buckets and labels, stored-value decoding, per-bucket edit/save/reload, retired favourites reasons and the removed onboarding step/screen id. Nine focused UI tests passed on iPhone 17 Pro Latest (iOS 26.0): other-profile battery and floating widgets at default and accessibility XXXL sizes, own-profile battery following a saved High availability plus a floating external-link action with a 44-point target, no favourites toggles or onboarding step, the explorer onboarding path, other-profile availability and Wish to Collab, flush cover geometry, the largest-text Settings target, the report/block menu, and widget link retention. Earlier attempts in the same session failed twice on the new own-profile test (a fixture already had a YouTube link, and the link target measured 21 points) and were fixed before the final run. Default and accessibility screenshots were inspected. The full UI suite, Staging build and live backend were not run.

Previous experiment verification (before the reversal): 89 unit tests and three focused UI tests passed, including all four banner destinations and accessibility-XL text. Ten configuration tests, the Staging build and artifact inspection passed. All three app-icon PNGs were 1024 × 1024 without alpha. The full UI suite was not rerun; this did not verify live backend features.

Floating-card verification: 88 unit tests passed. Seven targeted UI tests passed across the final focused runs, covering all prompt destinations, request acceptance → first message, tab navigation ownership, Crew controls, request types, and normal/accessibility-XL cards. Default and accessibility screenshots were inspected for Feed, Crew, Requests, Create and My Projects. Project thumbnails are decorative inside explicitly labelled project buttons, keeping accessibility targets inside the visible card. Ten release-configuration tests and the Staging build/artifact check passed. The full UI suite was not rerun.

Crew follow-up verification: regenerated the Xcode project so the Crew unit-test file is included. All 85 unit tests passed, including Medusa asset dimensions/transparency and long-name/Dynamic Type sizing. Two focused UI tests passed for default/accessibility-XL action layout, opening chat, and removal confirmation. Both screenshot sizes were visually inspected. Ten configuration checks and the Staging build/artifact check also passed. These results remain local validation, not live release verification.

Follow-up verification: 83 unit tests and six targeted UI tests passed. Coverage includes Feed inbox navigation, Profile-only Settings placement, largest accessibility text, all five tabs, Crew chat actions, profile report/block controls, and the completion-card edit action. Ten release-configuration checks and the Staging build/artifact check passed. All five tab roots were visually inspected on iPhone 17 Pro Latest. These results do not establish live backend behavior or production release readiness.

### Independent profile QA — Astra, October 28

Reviewed Fable's profile changes against base `528c53e`. No blocking findings. Removed two newly added source comments to comply with coding instructions; no behavior changed. Reviewed compatibility decoding, edit/save/reload of every availability bucket, public/private fields, retired favourites surfaces and matching reasons, onboarding route order, floating-card layout and external-link targets. Existing stored favourites are retained only for compatibility. The separate taste-card screen remains unchanged.

Independent run: `/tmp/kizuki-astra-profile-qa.xcresult`, iPhone 17 Pro Latest, iOS 26.0.1. Result: 92 unit tests passed, one existing local-backend integration test (`localHealthAndSignedOutSession`) skipped, six focused UI tests passed; ten release-configuration tests passed separately. The aggregate result is 98 passed, one skipped, zero failed. UI coverage includes low/high availability, default and accessibility XXXL widget layouts, editing and saving availability plus an external link, the removed favourites screens, explorer onboarding, other-profile requests and flush cover geometry. Exported screenshots in `/tmp/kizuki-astra-profile-qa-shots/` were inspected. The tested code revision is identified by the final commit SHA in the PR review record.

Required GitHub checks remain a separate gate. No full UI-suite, new Staging build, live profile persistence, real-device color inspection or provider authentication verification is claimed. About 2.5 GiB disk space remained; existing DerivedData was reused. Fable authored the feature; Astra performed independent QA. Next feature author: Astra, reviewer: Fable 5.1. Related: [[README]], [[AGENTS]], [[ProfileView]], [[Models]].

## Previous experiment — superseded

October 28, 2026: initial reversible local design experiment, not a locked product decision.

- Search, Suki, My Projects and Profile no longer show large screen-name headings.
- Minimal is the default. The left side stays visually empty; VoiceOver retains a screen heading.
- Settings → Header appearance → Symbols displays the existing Figma-derived search, project and profile marks, and the existing Suki mascot.
- The Home Kizuki logo, Settings/Messages actions, bottom tab names, detail titles and editing navigation remain unchanged.
- The choice persists locally under `kizuki.headerAppearance`; it does not modify the user's profile or matching settings. The preference UI is Debug-only, alongside the existing prototype Settings screen.

Reference inspected: Figma file `nPqXTMCtd3OVZTSU7Y2uN3`, node `1609:387`. This is a single 1280 × 896 raster icon sheet, not separately exportable symbols. This pass reuses the existing bundled vector family rather than cropping the raster or claiming new vector exports from it. No Figma file was changed.

The source URL: https://www.figma.com/design/nPqXTMCtd3OVZTSU7Y2uN3/Kizuki-App--Copy-?node-id=1609-387 .

## Previous experiment verification

83 unit tests, both link-editor UI tests and the new header-style UI test passed. The first header test incorrectly matched bottom-tab text as a screen heading; the assertion was narrowed to the header accessibility identifiers and the test passed on rerun. Both styles retain Settings, Messages and all four tab selections. Ten release-configuration tests and the Staging build/artifact check passed. Search was visually checked in both modes on iPhone 17 Pro Latest; the links section and branded cards were also inspected. Screens remain Debug/local, not a live release implementation.

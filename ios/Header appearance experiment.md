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

Feed now has a “Your next move” carousel with four state-driven prompt types:
- Finish an owned draft: opens that project. Any collaborating user with a draft can resume it, regardless of their original start/join intent.
- Review incoming pending requests: opens Suki → Requests → Incoming and resets stale detail navigation.
- Finish profile basics: opens Edit profile and disappears once the existing completion rules are satisfied.
- Say hello to a Crew connection with an empty conversation: opens that chat and disappears after a message. Fixture request acceptance no longer inserts a fabricated message on the user's behalf.

Only applicable prompts appear. Blocked people and resolved requests are excluded. Inspiration-only users do not receive collaboration prompts. No unread status, freshness, deadlines or urgency is invented. Accessibility text sizes use a vertical prompt list instead of a horizontal carousel. These are Debug/local screens backed by repository state, not a live notification service.

Floating-card verification: 88 unit tests passed. Seven targeted UI tests passed across the final focused runs, covering all prompt destinations, request acceptance → first message, tab navigation ownership, Crew controls, request types, and normal/accessibility-XL cards. Default and accessibility screenshots were inspected for Feed, Crew, Requests, Create and My Projects. Project thumbnails are decorative inside explicitly labelled project buttons, keeping accessibility targets inside the visible card. Ten release-configuration tests and the Staging build/artifact check passed. The full UI suite was not rerun.

Crew follow-up verification: regenerated the Xcode project so the Crew unit-test file is included. All 85 unit tests passed, including Medusa asset dimensions/transparency and long-name/Dynamic Type sizing. Two focused UI tests passed for default/accessibility-XL action layout, opening chat, and removal confirmation. Both screenshot sizes were visually inspected. Ten configuration checks and the Staging build/artifact check also passed. These results remain local validation, not live release verification.

Follow-up verification: 83 unit tests and six targeted UI tests passed. Coverage includes Feed inbox navigation, Profile-only Settings placement, largest accessibility text, all five tabs, Crew chat actions, profile report/block controls, and the completion-card edit action. Ten release-configuration checks and the Staging build/artifact check passed. All five tab roots were visually inspected on iPhone 17 Pro Latest. These results do not establish live backend behavior or production release readiness.

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

# Header appearance experiment

Related: [[KizukiIcons]], [[Components]], [[SettingsViews]], [[Portfolio widget integration]].

## Current direction — October 28 follow-up

The user superseded the experiment after PRs #5 and #6 merged:

- The global Messages/inbox shortcut belongs only on Feed. Feed keeps its Kizuki logo and existing layout; it no longer has Settings.
- Settings is available only at the top right of the own Profile, through a three-line menu over the cover. Other people's profiles retain their separate report/block menu.
- Search, Suki and My Projects have no reserved header row. Their content starts at the safe area rather than below an empty header.
- Profile cover, work cards and collab gallery, Suki sections and project rows extend to the horizontal screen edges. Text, form controls and touch targets retain internal padding and system safe areas.
- The Minimal/Symbols preference is removed. Existing stored preference values are ignored.
- Contextual chat actions inside Crew and profile content are preserved; these are not the global inbox shortcut.

This applies to the Debug/local tab-root UI. Detail navigation and edit-form spacing are retained. No newly extracted artwork from the referenced raster sheet is included.

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

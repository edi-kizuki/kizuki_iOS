# Header appearance experiment

Related: [[KizukiIcons]], [[Components]], [[SettingsViews]], [[Portfolio widget integration]].

October 28, 2026: reversible local design experiment, not a locked product decision.

- Search, Suki, My Projects and Profile no longer show large screen-name headings.
- Minimal is the default. The left side stays visually empty; VoiceOver retains a screen heading.
- Settings → Header appearance → Symbols displays the existing Figma-derived search, project and profile marks, and the existing Suki mascot.
- The Home Kizuki logo, Settings/Messages actions, bottom tab names, detail titles and editing navigation remain unchanged.
- The choice persists locally under `kizuki.headerAppearance`; it does not modify the user's profile or matching settings. The preference UI is Debug-only, alongside the existing prototype Settings screen.

Reference inspected: Figma file `nPqXTMCtd3OVZTSU7Y2uN3`, node `1609:387`. This is a single 1280 × 896 raster icon sheet, not separately exportable symbols. This pass reuses the existing bundled vector family rather than cropping the raster or claiming new vector exports from it. No Figma file was changed.

The source URL: https://www.figma.com/design/nPqXTMCtd3OVZTSU7Y2uN3/Kizuki-App--Copy-?node-id=1609-387 .

## Verification

83 unit tests, both link-editor UI tests and the new header-style UI test passed. The first header test incorrectly matched bottom-tab text as a screen heading; the assertion was narrowed to the header accessibility identifiers and the test passed on rerun. Both styles retain Settings, Messages and all four tab selections. Ten release-configuration tests and the Staging build/artifact check passed. Search was visually checked in both modes on iPhone 17 Pro Latest; the links section and branded cards were also inspected. Screens remain Debug/local, not a live release implementation.

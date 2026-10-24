# iOS build readiness — 2026-10-24

Related: [[playbook]], [[00-what-exists]], [[AGENTS]], [[CLAUDE]], [[README]].

## Confirmed workspace and stack

- Work only in `/Users/edisonabdiel/Projects/kizuki_iOS`; set command working directories explicitly when the T3 thread is bound to scratch.
- Git origin: `https://github.com/edi-kizuki/kizuki_iOS.git`. Repository has no initial commit yet.
- Current Notion requirements specify iPhone, iOS 17+, Swift/SwiftUI, and Supabase. Older React Native material is superseded by the user's native iOS direction.
- Supabase project: `enosggckdxjiaqtxalhg`. Read access verified; public table list empty. Development/staging/production role remains unconfirmed.

## Tooling verified this round

- Xcode 26.0.1, build 17A400. iOS 26.0 simulator runtime and iPhone simulators are available. iOS 17 runtime coverage is not installed in the observed simulator list.
- Installed XcodeGen 2.46.0. Use `project.yml` to generate the Xcode project; do not hand-edit `.pbxproj` files.
- Registered XcodeBuildMCP in both Codex global config and Claude user config: `npx -y xcodebuildmcp@latest mcp`.
- Direct MCP initialization succeeded with XcodeBuildMCP 2.7.0; tools/list returned 24 tools including build_sim, build_run_sim, test_sim, screenshot, and snapshot_ui.
- `claude mcp get XcodeBuildMCP` reports Connected. Claude model-account login is separate; the earlier model authentication failure has not been reverified.
- Existing agent sessions may need a new session to load newly registered tools. No app build has been attempted because no app project exists.
- Prefer T3 device tools for opening the shared simulator panel and interactive verification. XcodeBuildMCP supplies build/test/debug tools.

## Assets received

- Imported all 10 images from the user-provided `Kizuki illustrations.zip` under `docs/design/illustrations/`, preserving names and bytes.
- All images passed decoding checks; inventory and dimensions are in `docs/design/illustrations/README.md`.
- Contact-sheet inspection shows website sections, a long landing-page export, and mobile splash/entry/onboarding screens. Illustrations are embedded in these compositions.
- These are JPG/PNG raster references, not standalone vectors or an editable Figma file. Obtain separate artwork exports before exact production integration. Do not turn full-screen screenshots into app UI.
- The ZIP provides local app and website references despite the illustrations-file MCP editor-permission limitation. It does not establish complete production asset coverage or approve older copy/features.

## Required work before the first prototype

1. Finish source intake: read detailed linked technical, data/RLS, recommendation, safety, consent, and user-story pages. Existing intake covers the project and nine linked pages, not every specification.
2. Reconcile current Notion navigation/onboarding with older Figma variants. Resolve Start destination and compensation-rule contradictions. Record decisions and a glossary.
3. Agree first milestone and acceptance scope. No delivery date is approved.
4. Freeze the selected screen structure and design tokens: colors, fonts and their licenses, spacing, component states, light/dark behavior, accessibility, and illustration placement. Reuse approved Figma direction; do not assume the playbook's Purse styling.
5. Choose bundle identifier and app display name. Generate `project.yml`, SwiftUI app entry point, fixtures, launch-argument screen router, and a repeatable screenshot workflow.
6. Build and run the fixture prototype on the simulator. Review actual rendered screens, including Dynamic Type, VoiceOver, error/empty/loading states, and relevant device sizes.

## Required work before a live backend

- Confirm the Supabase environment role and separation of development and production.
- Define reviewed data models, API contracts, fixture/live implementations, migrations, authorization and RLS, storage access, and deletion/retention behavior.
- Configure Apple/Google/email authentication and redirect/deep-link behavior to match approved specs. Keep server credentials off-device and out of git.
- Implement the approved recommendation algorithm after its detailed spec is read; no external model is implied.
- Define request acceptance before messaging, reporting/blocking/moderation, collaboration confirmation, consent, and analytics against the canonical requirements.
- Supabase CLI is absent. Install it when starting local backend/migration workflows; establish the container-runtime prerequisite if using the local Supabase stack.
- Verify meaningful unit/integration/UI tests, including RLS denial cases. No remote schema changes were made during setup.

## Required for device distribution and TestFlight

- Apple Developer membership/team, signing setup, registered bundle ID, and App Store Connect app record.
- Archive/upload workflow and device testing. These are not required for an unsigned simulator prototype.
- Privacy disclosures/manifests where applicable, permission strings, account deletion, support/privacy URLs, and App Store review requirements based on actual functionality.

## Playbook workflow tools still outstanding

Claude plugin inventory does not list the playbook's Matt Pocock skills, all-ios-skills, compound-engineering, swift-lsp, frontend-design, code-review, pr-review-toolkit, or claude-mermaid packages. They were not installed in this round. Archify availability was not verified. These assist the workflow; they are not iOS build dependencies.

Set up the relevant skills when their phases begin. The playbook also calls for local decision tickets/Wayfinder, ADRs, a project hub, independent review, and session handoffs. Inspo, Mobbin, and Palate support design reference work and are not required to compile the app. A hub deployment needs its own host and password setup. No hub or deployment was created in this round.

## Recommended next milestone

Superseded by user direction: start development with a production-quality native foundation, specifications, meaningful tests, and Supabase integration. Figma guides an iterative UI. Fixtures are for tests and previews. Separate production artwork is not a kickoff prerequisite. Use Blobatar for profile pictures. Keep unresolved product decisions explicit.

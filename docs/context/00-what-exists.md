---
title: Kizuki — what exists
created: 2026-10-24
updated: 2026-10-24
tags: [project/kizuki, intake]
status: intake-recorded-with-access-limitations
---

# Kizuki — what exists

Related: [[playbook]], [[AGENTS]], [[CLAUDE]], [[2026-10-24-notion-source-extracts]], [[2026-10-24-figma-screen-inventory]].

## Scope and evidence

Read-only source research and local documentation. No implementation or architecture decisions.
Source verification date: 2026-10-24.
Successful authentication is recorded separately from successful source reads.

## Repository

- Working directory: `/Users/edisonabdiel/Projects/kizuki_iOS`.
- Workspace rule: run project commands and write files in this directory explicitly; a T3 scratch directory is not the project root. The user confirmed keeping `kizuki_iOS`. No rename is required.
- Origin: https://github.com/edi-kizuki/kizuki_iOS (`.git` suffix in local remote).
- Initial inspection: unborn `main`; no commits. Only `docs/playbook.md` existed outside `.git`.
- No app source, Xcode project, project generator specification, tests, or local design exports existed at intake start.
- Applicable ancestor instructions: `/Users/edisonabdiel/AGENTS.md`. Keep prose concise and link new notes with Obsidian wikilinks.

## User decisions and process guidance

- User decision: native iOS app.
- User decision: Supabase project `enosggckdxjiaqtxalhg`.
- User authorization: appropriate Codex/Claude models. No subagents in this research task.
- Parent owns authentication and configuration. This task does not change them.
- [[playbook]] recommends intake before planning, SwiftUI for native prototypes, and XcodeGen for project generation. These are playbook recommendations, not architecture decisions made by this intake.
- Purse is the playbook's example app. Its finance domain, households, bank feeds, features, styling, and delivery dates are not Kizuki requirements.

## Sources and actual access

- Notion specs: https://app.notion.com/p/Kizuki-16858cc06d1b805d9639d7810bd0a781
  - Parent reports successful OAuth. Notion tools appeared after the initial catalog scan.
  - Verified: `notion_fetch` returned the Kizuki project page and the nine linked pages listed below. Specs were actually read through the connector; no browser login was needed.
  - Returned page `verification.state` is `unverified`. This is Notion's page verification field, not an access failure or a claim of editorial approval.
  - Responses did not expose `truncated`, `unknown_block_count`, or `unknown_block_ids`. No explicit truncation warning was returned. Linked child pages and mentions are not automatically included.
- App Figma: https://www.figma.com/design/XIe9K1RrE3wgLnlBJ59p1i/Kizuki-App?node-id=0-1
  - Verified: `get_metadata`, file `XIe9K1RrE3wgLnlBJ59p1i`, node `0:1`, returned canvas `App - Version 1` and its node tree.
  - Four specific frame screenshots were downloaded and visually inspected. All four local files contain valid PNG data.
  - This establishes metadata access to this page, not exhaustive file coverage or a verified interactive prototype.
- Illustrations Figma: https://www.figma.com/design/fLQY6jJbQ0adtsqjXd5jg2/Kizuki-illustrations?node-id=0-1
  - Actual `get_metadata` call failed: “Looks like you don't have edit access to this file. The file owner can share it with you and make you an editor.”
  - Tool returned `isError: true`. No illustration content was read. This is an MCP access limitation; ordinary browser viewing permission is unverified.
- Supabase:
  - `get_project_url` returned `https://enosggckdxjiaqtxalhg.supabase.co`.
  - `list_tables` with `schemas: ["public"]`, `verbose: false` returned `{"tables":[]}`.
  - Project URL and public-schema table-list access are verified. The result does not establish that every schema or the entire project is empty. Other schemas, policies, storage, functions, migrations, and row data are uninspected.

## Notion pages actually read

Fetched content is preserved in [[2026-10-24-notion-source-extracts]]. Dates below are returned page edit dates, not proof of approval.

- [Kizuki project](https://app.notion.com/p/16858cc06d1b805d9639d7810bd0a781): 2026-10-24.
- [Canonical Product Brief](https://app.notion.com/p/36458cc06d1b81e68ce9c391f6ec9daf): 2026-07-17.
- [Development](https://app.notion.com/p/16b58cc06d1b80b6ba80ca73a978865a): 2026-10-24, last read version edited at 15:42:40 UTC.
- [Onboarding Specification v3.1](https://app.notion.com/p/2a658cc06d1b808c9d19c6665133dd82): 2026-10-24.
- [Core User Flows](https://app.notion.com/p/3a058cc06d1b8109a00ee73defc14bda): 2026-07-17.
- [Product Requirements](https://app.notion.com/p/17e58cc06d1b8095b912df2413408d15): 2026-07-17.
- [App Optimization Plan](https://app.notion.com/p/36458cc06d1b819493e5cb164946b0ac): 2026-07-17.
- [Roadmap](https://app.notion.com/p/18e58cc06d1b809b8dfdccedb8a391e7): 2026-07-17.
- [iOS MVP Build Plan](https://app.notion.com/p/40358cc06d1b811e9e83ff5fd2fdd7c0): 2026-10-24, last read version edited at 15:43:01 UTC.
- [Site Map](https://app.notion.com/p/17e58cc06d1b80b6ab18f0638fc27b91): 2026-10-24.

Detailed technical architecture, data model/RLS, backend jobs, recommendation algorithm, taste strategy, connector strategy, analytics, safety, user stories, voice, personas, and design-reference pages are linked from these sources but were not separately fetched. Their detailed contents remain unverified in this intake. No access failure is claimed for unattempted pages.

## What the app is and who it serves

The project page and Canonical Product Brief describe Kizuki as a cross-disciplinary creative collaboration product: “Find your people. Make something real.” It helps people find collaborators and projects through capability, taste, intent, availability, work mode/city, compensation expectations, and trust.

The named audience is filmmakers, musicians, visual artists, and mixed-practice creators. The first recruited cohort is Berlin indie filmmakers and the collaborators their projects need. This is a launch cohort, not a film-only product boundary. Product Requirements names individual creators as the MVP user type; collective and business accounts are later scope.

The core loop in the brief is creative identity and intent → relevant people/projects → understandable match reasons → contextual request → acceptance and conversation → completed collaboration → confirmed Made Together outcome. The north-star measure is confirmed meaningful collaborations per monthly active creator. No usage, traction, or completed-collaboration evidence was inspected.

## Decisions already recorded in sources

These are source statements, not choices made by this research task.

- The current Development page and onboarding v3.1 specify iPhone, iOS 17+, Swift/SwiftUI, and Supabase. Android and web are outside this build. This agrees with the user's native iOS decision.
- Onboarding v3.1 records minimum age 18, English-only launch, and Apple/Google/email sign-in.
- Canonical navigation is Discover, Projects, People, Inbox, You. Made Together belongs inside Discover and profiles.
- Start, Join, and Explore share taste capture and serendipity controls. Optional work/reference linking has separate public-display and recommendation-use consent, both off by default.
- Request acceptance precedes messaging. Confirmed collaboration outcomes require participant confirmation. Reporting, blocking, moderation, and an appeals path are specified.
- Launch connectors are links/manual entries and permitted metadata. The sources do not promise general Spotify, Instagram, or TikTok OAuth importing.
- The brief and requirements exclude events, public ratings, full project management, payments/escrow/contracts, native video hosting, and paid organic ranking from MVP. The iOS build plan also excludes ads and premium from this build.
- The latest Development page says recommendations and taste capture use Kizuki's own algorithm, with no external model, and labels Jev integration “Parked.” Its detailed algorithm page was not read. An earlier read during this intake named Jev as a scorer; the later source snapshot supersedes that observation. This intake does not select or design the algorithm.
- The iOS build plan contains milestones M0–M5 and explicitly has no delivery dates. A plan is not evidence that any milestone has been implemented.

## Existing screens and flows

Full direct-child inventory: [[2026-10-24-figma-screen-inventory]]. The inspected page has 140 direct children, including 114 frames. Variants, components, and reference material are included; this is not a count of distinct screens.

### Observed in Figma metadata

- Entry/auth: splash variants; Login / Create Account (`1312:11831`, `1526:4399`); Apple/Google sign-in (`1312:11854`); username and age-check states (`1480:4256`); duplicate-handle and eligibility errors; profile-photo states (`1312:11996`, `1312:12172`).
- Onboarding: project-type choices for visual arts, music, film/video, and hybrid (`1312:11455`, `1344:11498`, `1361:11847`, `1344:11806`, `1361:11680`); roles; onboarding goals; portfolio linking (`1312:12814`); location access (`1312:13188`).
- Discovery: five named Feed / Discovery Page variants, including recommended projects/people (`1312:8064`), project listings (`1468:4887`), and people listings (`1473:5741`).
- Search: collab/search variants (`1312:9342`, `1468:5306`) and recent/name search (`1312:9406`).
- Profiles: bio/open-to-work (`1312:9852`), projects/collabs (`1312:10050`), portfolio (`1312:10189`), empty state (`1312:10251`), and creative-profile editing (`1411:3033`, `1418:3514`).
- Messaging: chat (`1312:10374`), populated list (`1312:10492`), first state (`1312:10709`), and search (`1312:10773`).
- Projects/posts: create-project form (`1361:12567`); project detail/open/closed variants (`1485:5384`, `1485:6118`); comments; payment-choice variants (`1480:4806`, `1485:5674`); several Post Page frames.
- Settings: account, notifications, privacy/safety, collaboration preferences, connected apps, region/language, help, and legal/about (`1312:8654` through the named variants ending at `1312:9294`).
- Components section (`1290:7947`) and additional unlabeled/reference frames exist. They were not audited as a complete design system.

Canvas annotations explicitly name “App Entry: Splash → Sign up / Login → Account Creation,” “Allow notifications → Login,” and “Profile page Projects → Collabs → Portfolio.” These are annotation text, not verified prototype connections.

### Screenshots visually inspected

Exports are under `docs/design/` and embedded in [[2026-10-24-figma-screen-inventory]].

- `2026-10-24-figma-entry.png`, node `1526:4399`: dark brown entry screen, orange logo/action, Create Account and Log in.
- `2026-10-24-figma-discover.png`, node `1312:8064`: dark recommendation cards on a pale blue-gray background; recommended projects/people and an icon-based bottom bar.
- `2026-10-24-figma-project.png`, node `1485:5384`: photo-led Music Session detail, roles, time investment, Open state, and “Create a collab.”
- `2026-10-24-figma-profile.png`, node `1312:9852`: bio, follow action, work/music presentation, skills, availability, external-platform icons, and a collaboration action.

The selected frames show existing visual treatments. No palette, typography, navigation, or variant was approved or changed by this intake.

### Flows specified in Notion

- Onboarding v3.1: sign-in → handle → terms/eligibility → realm/intent → shared taste seed, pairwise choices, serendipity, roles → Start project setup / Join interests and compensation / Explore focus → availability where applicable → work mode/city → optional work/references → preview. Skip and resume are specified.
- Start: define project and needed roles, preview, publish, invite relevant people, fill/close roles, renew stale projects.
- Join: discover a project, inspect match reasons, send a project/role request, receive acceptance, open the conversation.
- Find people: filter creators, inspect profile/work/reasons, send a contextual request, then converse after acceptance.
- Explore: save/hide and more/less-like-this feedback shape recommendations and serendipity.
- Complete: propose completion, obtain confirmation, publish a Made Together outcome with credits.
- Work/reference linking: preview display and recommendation use, then edit/hide/disconnect/delete.

These are written requirements. Their complete screen coverage and interactive behavior in Figma remain unverified.

## Contradictions and gaps

1. **Platform drift.** July Canonical Product Brief, Product Requirements, and Roadmap still say React Native/React. October Development, onboarding v3.1, and the user say native iOS. The intake records the user's decision and preserves the conflicting source statements.
2. **Navigation drift.** Figma search-frame text includes Home, Search, Suki, Create, My Projects. Notion specifies Discover, Projects, People, Inbox, You. No Figma variant has been identified as the approved replacement.
3. **Permission timing.** Figma includes Enable Location Access (`1312:13188`) and “Allow notifications → Login.” Notion defers location until a nearby feature and notifications until request activity.
4. **Messaging gate.** Figma settings (`1312:8951`) include “Who can message me” with “anyone.” Notion requires acceptance before conversation. The implementation meaning of the Figma setting is unknown.
5. **Payments and project wording.** Figma contains Apple Pay/Google Pay choices and event-like Music Session copy. Notion excludes payments and events from MVP. A visual payment choice does not establish an approved commerce requirement.
6. **Onboarding version.** Figma metadata exposes older goal/project/role/portfolio screens. Complete coverage of v3.1 taste cards, pairwise choices, separate consent, Start/Join/Explore branching, and eligibility states has not been demonstrated.
7. **Post-onboarding destination.** Site Map says Start lands on an unpublished draft and suggested people. Onboarding v3.1 says Start gets a “Finish your project” card at the top of Discover after completion. Exact destination needs reconciliation.
8. **Compensation wording.** Onboarding's confirmed-decision callout says paid seekers pair only with paid hiring. Its matching table also allows Paid preference → Open-to-either project. The precise allowed case needs confirmation.
9. **Required fields differ by document.** July Product Requirements' browsing/request-ready lists differ from v3.1's explicit Browse/Send request/Publish contract, which includes terms/age and conditional email, role, availability, and work-mode requirements.
10. **Illustrations blocked.** The connector requires edit access for the supplied illustrations file. Asset contents, licensing, and export coverage are unknown.
11. **Limited backend evidence.** Public table listing is empty. This does not verify the broader project setup or explain its environment role.

No app source, build, deployed service, or working user journey was verified. No authentication settings, database objects, or remote designs were changed. No push or deployment was performed.

## Asset and tooling update — 2026-10-24

The later user-provided `Kizuki illustrations.zip` supersedes the earlier JavaScript-only upload as a usable visual source. Ten JPG/PNG images are imported under `docs/design/illustrations/`; see [[README]] there for dimensions. All decoded successfully. Visual inspection shows app screens and website sections with embedded illustrations. Standalone vectors and editable artwork are still absent. The earlier MCP editor-permission limitation remains, but local references are now available.

XcodeBuildMCP 2.7.0 is registered for Codex and Claude. MCP initialization and tool discovery passed; Claude reports Connected. XcodeGen 2.46.0 is installed. See [[2026-10-24-ios-build-readiness]] for requirements, remaining decisions, and setup evidence.

## Open questions

### Uploaded illustration candidates — 2026-10-24

All 100 supplied `.min.js.br` attachments contain readable JavaScript bundle code, despite their `.br` suffix. They were inspected as text without execution. These are not standalone illustration exports. No Kizuki illustration assets have been verified from these uploads. Obtain SVG, PNG, PDF, or a Figma `.fig` export, or resolve the illustrations-file connector permission. The attachments were not copied into the app repository.

1. Which Figma page and frame variants are approved for onboarding v3.1 and the current navigation?
2. Can the parent resolve the illustrations-file connector permission? Are approved, licensed exports available?
3. Which source should resolve the post-onboarding Start destination and compensation-table conflicts?
4. Which older Figma payments, events, Suki, following, and unrestricted-contact elements are obsolete?
5. What is the role of Supabase project `enosggckdxjiaqtxalhg`—development, staging, or production—and what exists outside `public`?
6. Have the detailed linked safety, consent, recommendation, data, and user-story documents been reconciled with the October source updates?
7. Who owns the taste-card rights, facet taxonomy, and tagging process? The iOS build plan still records these as open work.
8. Which existing design tokens and assets are approved? The inspected screenshots do not establish a frozen design system.
9. What delivery target and acceptance scope has the user approved? The source build plan sets no dates.

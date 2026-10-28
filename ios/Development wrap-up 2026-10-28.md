# Development wrap-up — October 28, 2026

Related: [[README]], [[AGENTS]], [[Header appearance experiment]], [[Portfolio widget integration]], [[Provider icon credits]].

## Scope and delivery

This records the October 28 local development day (UTC+01:00), including changes after midnight. Source snapshot: `17ffd19b2fb74773b089c79aa8e0aa5f8c4b0933`, branch `feat/subtle-feed-brand-2026-10-28`, PR #8. Documentation-only follow-ups do not change the tested source snapshot. This is a Debug/local prototype, not a production release.

GitHub observed at wrap-up: PRs #5, #6 and #7 are merged; PR #8 is open. PR #7 merged October 28 at 13:58:56 UTC. PRs #5 and #6 merged shortly before midnight UTC on October 27, which is October 28 locally. Nothing in this wrap-up authorizes merging #8 or deploying.

## Final feature state

| Area | Final behavior | Revision / notes |
| --- | --- | --- |
| Portfolio editing | Invalid or unfinished URL input no longer disables the entire profile Save action. Provider sheet changes are confirmed or cancelled separately; profile Save remains atomic. Normalization and origin validation are shared. | `e90e798`; [[Portfolio widget integration]] |
| Providers | YouTube, Instagram, Letterboxd, Bandcamp, SoundCloud and TikTok use provider logos and optional Show on profile toggles. Hidden links retain their URL. | External links only, not authenticated accounts or embedded playback. |
| Navigation | Global inbox is Feed-only. Own Profile settings uses a top-right three-line menu. Other tabs have no reserved screen-title header. Contextual chat and safety menus remain. | `e59fe14`; replaces the Minimal/Symbols experiment from `68c6257`. |
| Crew | Your Crew uses the Medusa cropped from the specified Figma Drawings image. Crew actions remain accessible. | `1201929`; raster resolution limits remain documented. |
| Cards | Crew, Requests, Create, Drafts/Published/Past projects, availability and Portfolio use shared floating surfaces: 20-point corners and 12-point outer gutters. Backgrounds and profile covers remain flush. | `6c429b2`, `b357c55`. |
| Feed notices | Subtle inline blue-tinted action rows replace Your next move and solid-blue banner experiments. Draft completion, incoming requests, incomplete profile and new Crew conversation prompts follow actual local state. | `bf4103e`; 14% Kizuki Blue over Baby Blue, charcoal text; no urgency or unread counts invented. |
| Branding | Original logo restored; Feed mark is palette yellow, inbox glyph palette orange. Original brand family retained for app icons. | `2e3a0a6`; temporary concept-eight branding from `b1493c4` is superseded. |
| Cover layout | Own-profile cover reaches both screen edges and behind the status area. Settings respects the top inset; readable content gutters remain. | `bf4103e`; custom photo adds a contrast scrim in `17ffd19`. |
| Availability | Battery communicates current weekly capacity: red under 5 hours, yellow 5–9 hours, green 10+ hours. Labels accompany color. Edit profile changes persist locally. | `b357c55`; green/red are semantic iOS values, yellow is the brand token. |
| Favourites | Removed from profile, onboarding, privacy controls and fixture recommendation reasons. Legacy serialized fields remain for compatibility, with new consent defaults off. | `b357c55`; taste-card screen remains; 10 collaborator / 7 explorer onboarding screens. |
| Photos | Edit profile supports native selection, preview, save/cancel and removal of portrait/cover. Removal restores Blobatar/generated cover. Portrait updates propagate to person-backed surfaces. | `17ffd19`; on-device persistence only, not cloud upload. |
| Copy | Removed Your profile basics. Profile Work and editor Your links both become Portfolio. | `17ffd19`. |

Existing four-role selection (one main plus up to three secondary, including Painter) remains. The former film-only taste fallback is rejected; no new taste-inference design was approved today.

## Photo safety and persistence

- Input is bounded to 25 MB, 100 megapixels and 20,000 pixels per dimension; animated/multiframe images are rejected.
- ImageIO downsampling corrects orientation. Portraits are at most 512 pixels; covers at most 1,600 pixels. JPEG output is capped at 1 MB and strips original GPS/EXIF metadata.
- Save is unavailable while processing. Cancelling discards drafts. A repository failure leaves the saved profile unchanged. Existing snapshots decode without photo fields.
- Photos share the existing atomic local profile snapshot. Ordinary Debug launches persist; fixture, gallery (`-screen`) and test launches intentionally use ephemeral state.
- The editor explicitly discloses that photos remain on this device and cloud upload is not connected. No broad photo-library permission was added.

## CI investigation and changes

Two different failures must not be conflated:

1. Run `40762509022`, iOS job `123077871773`, was cancelled before any step because a hosted runner was not acquired. GitHub annotations reported runner capacity constraints. The workflow now selects `macos-15-intel`, retaining the Xcode 26.0.1 pin.
2. Run `40769335775` at `b357c55` acquired a runner and failed `testEntryOnboardingAndEveryTab`. The test still tapped Continue ten times after Favourites removal. The ten-screen route needs nine Continue taps followed by Enter Kizuki. The repaired test asserts the numbered steps and unnumbered notification/location primers.

Result artifact upload now includes hidden files, restricted to `.build/*.xcresult`. Tests, safeguards, required-check names and timeouts were not disabled or weakened.

At the initial wrap-up inspection, run `40777742399` for `17ffd19` had passed `local-backend`; `ios` was still running. That is not a complete CI pass. Any subsequent documentation commit has its own required-check gate.

## Validation evidence

Device: iPhone 17 Pro Latest, iOS 26.0.1. Existing DerivedData reused at `/tmp/kizuki-roles-persistence-build`. Result bundles were re-read during wrap-up; counts below are xcresult aggregate tests, not parameter-expanded device totals.

| Validation | Actual result | Evidence / qualification |
| --- | --- | --- |
| Complete local suite | 130 passed, 2 skipped, 0 failed | `/tmp/kizuki-photos-full-suite.xcresult`: 95 unit and 35 UI passed; opt-in backend and live Supabase smoke tests skipped. |
| Final custom-cover scrim | 3 focused UI tests passed | `/tmp/kizuki-photo-final-cover.xcresult`: photo save/cancel/remove, largest-text editor, flush cover. Full suite preceded this scrim-only adjustment. |
| Release configuration | 10 passed | `python3 scripts/test-release-config.py`; rerun during wrap-up. |
| Local backend guard | 2 passed | `python3 scripts/test-local-guard.py`; rerun during wrap-up. |
| Screenshot-gallery guard | 5 scenarios passed | `scripts/test-screenshot-gallery-guard.sh`; rerun during wrap-up, no simulator interference. |
| Runtime release guard | 4 cases passed | `scripts/test-release-runtime-guard.sh`; rerun during wrap-up. |
| Debug artifact negative control | Passed | `test-release-artifact-negative-control.py` rejected the actual Debug binary with minimal system PATH during wrap-up. |
| Staging build/artifact | Passed in implementation pass | Compile/artifact verification only, not live staging behavior. |
| Production refusal | Passed in implementation pass | Release build correctly refused production under the existing guard. |
| Whitespace | Passed | `git diff --check`. |

Full-suite coverage includes onboarding/tab navigation, profile completion, Crew/request actions, external links and visibility, availability, Favourites removal, photo handling and save failures. Final screenshots are in `/tmp/kizuki-final-photo-shots/`; normal and largest-text states were inspected during implementation. These local temporary artifacts are not checked into Git. No second simultaneous simulator suite was started during the independent review.

## Engineering and attribution

- Future assisted commits use Edison Abdiel's noreply GitHub identity. This does not change repository ownership or rewrite earlier commits.
- Astra and Fable 5.1 alternate author/reviewer roles under [[AGENTS]]. Branding at `528c53e` received Fable review; availability at `b357c55` received Astra review.
- Photo/CI implementation at `17ffd19`: author Astra; Fable independent QA completed with no blocking code findings. Required iOS CI was still running at review handoff, so this is not ready-to-merge approval.
- Cline's diagnostic attempt failed with insufficient credits before investigation. Do not describe that as a diagnosis or successful repair. The recurring automation's end-to-end repair remains unverified; its local ledger and scheduling state are not application source.
- Disk space is constrained (6.9 GiB free at wrap-up inspection). Existing build products were reused; no source/user data was deleted.

## Remaining work and honest boundaries

1. Verify required CI on the final PR head. Independent code review found no blockers; any substantive follow-up needs independent re-check. No automatic merge.
2. Deploy/verify the live profile backend and implement authenticated cloud media storage, upload, deletion and access control. Local JSON persistence is not this integration. No new live staging account/profile test was run today.
3. Implement genuine provider authorization and consent-gated playback after provider registration/eligibility and backend prerequisites. Current Connect remains a disclosed link-entry flow.
4. Verify physical devices, other screen sizes and broader media-library/provider failure cases. No physical-device testing, TestFlight release or production deployment is claimed.
5. Resolve the remaining historical Notion contradictions and unaudited pages listed below. Today's targeted delta is saved and read-back verified, not a full-workspace audit.

Never include credentials, private configuration, raw photo snapshots or test-account data in the repository or Notion audit.

## Independent photo/CI review handoff

Claude Fable 5.1 reviewed exact source `17ffd19b2fb74773b089c79aa8e0aa5f8c4b0933` against `b357c55b2f6ff1f6bb7c92f9522260016be4f6a1`. No blocking code findings. Its unit bundle `/tmp/kizuki-review-unit.xcresult` reports **95 passed, 1 skipped, 0 failed (96 total)**. The initial reviewer message called this 96 passed; wrap-up read-back corrects that counting discrepancy. Its UI bundle `/tmp/kizuki-review-ui.xcresult` reports **5 passed, 0 failed**: onboarding route, photo save/cancel/remove, picker cancellation/headings, largest text and flush cover.

The reviewer additionally reported 17 adversarial image-processing cases run separately on macOS. Those are standalone script observations, not additional XCTest cases. Bounds, orientation, metadata stripping and malformed/multiframe rejection were exercised; valid HEIC, alpha/16-bit PNG and tiny images were accepted.

Nonblocking findings retained for follow-up:

- **Medium, runner capacity:** the temporary Intel runner workaround may not fit a full test suite plus release checks within the existing 30-minute job timeout. Observe the actual result before choosing a capacity adjustment. No timeout or guard was changed based only on this hypothesis.
- **Low, high-entropy images:** the bounded JPEG quality ladder can reject noisy large images rather than silently oversize the snapshot. The error path is graceful; cloud-media work should revisit compression policy.
- **Low, snapshot cost:** unrelated profile writes re-serialize the locally stored image bytes. Do not carry this prototype snapshot approach unexamined into a live sync layer.
- **Low, import concurrency:** cancelled task cleanup could clear a successor's loading flag, but disabled picker/removal controls prevented the reviewer from reaching this path. No required fix identified.

Cloud upload remains explicitly outstanding. At review handoff, GitHub `local-backend` passed and `ios` remained in progress on run `40777742399`. There was no GitHub-hosted review submission; this independent review is recorded in the repository and PR audit instead.

## Notion synchronization audit

Claude Fable 5.1 used the connected CollaboNation workspace. It updated **20 pages**, then re-fetched every page after its last edit: **23 read-backs**, including three repeated after corrections. Edit window: October 28, 22:24–22:28 UTC. Recorded application source is `17ffd19`, PR #8 open. Independent QA is recorded as complete with no blocking code findings; required iOS CI remains pending. This documentation-only follow-up does not change the application source recorded in Notion.

| Updated and read-back verified page | Notion page ID |
| --- | --- |
| Development hub | `16b58cc06d1b80b6ba80ca73a978865a` |
| iOS MVP Build Plan | `40358cc06d1b811e9e83ff5fd2fdd7c0` |
| UI/UX Design | `17b58cc06d1b804f9fc3f901c8c627c6` |
| Profile Creation | `d4482cf8a70b47cda742bcfe90d63816` |
| Onboarding Specification | `2a658cc06d1b808c9d19c6665133dd82` |
| Site Map | `17e58cc06d1b80b6ab18f0638fc27b91` |
| Core User Flows | `3a058cc06d1b8109a00ee73defc14bda` |
| Connected Portfolio Sources | `36558cc06d1b818e9e6cc5e42d14b0dc` |
| Portfolio Connector Data Strategy | `36558cc06d1b81e88156ce65f3268ad4` |
| iOS Technical Architecture | `40358cc06d1b81f282a9c4b15f2f0ac6` |
| iOS Build, Release & App Store Readiness | `40358cc06d1b8154b028cb6c0ab6790b` |
| Roadmap | `18e58cc06d1b809b8dfdccedb8a391e7` |
| Product Requirements | `17e58cc06d1b8095b912df2413408d15` |
| User Registration | `9de4fd8d86c848d786c22e31249ad5aa` |
| Projects Tab | `ab9d5ae0ea5b4de58ee0fdbbb6d3aa9e` |
| People Discovery | `bb8bcb65df514650a3f3e168d9fa4658` |
| Messaging | `ece5c2ef16c74859b98910093fc6efae` |
| Taste Capture Strategy | `36458cc06d1b817a8953f1579132813e` |
| Recommendation System | `36458cc06d1b818ea8adcd63eb7e841a` |
| Recommendation & Taste Algorithm v1 | `40358cc06d1b814eaf11e0ca373d73f6` |

Pages can be opened using `https://app.notion.com/p/<page ID>`. Superseded headers, top-bar placement, carousel/solid banners, temporary branding, old Portfolio headings, Favourites and PR #7 open-status claims were struck through with dated notes rather than deleted. Source inspection and read-back verified the key current behavior and honest local/cloud boundary. No credentials, private configuration or photos were copied.

### Remaining Notion gaps

The agent reports historical text below current-state callouts that still needs reconciliation: Onboarding C1's 5–10 label, O2 Mixed practice and C3 module list; Site Map diagrams; Product Requirements discovery/connector lists; People Discovery's old interface name; Architecture's planned 1,024-pixel cloud-avatar contract versus current local 512/1,600-pixel processing; Recommendation System's consented connector facets and cold-start step 8. These are not silently promoted to current implementation requirements.

Not audited this pass: Backend Functions & Jobs (including its obsolete TMDB favourites-picker proxy), Supabase Data Model & RLS, Trust & Safety, Storage and Databases, Product Analytics, Connector Signals, Facet Taxonomy, Canonical Product Brief, Made Together, Jev, User Stories index and research/business/archive pages. There was no full-workspace inventory. The 20-page delta is verified; the entire workspace is **not** claimed 100% synchronized.

## Publication gate

Before the documentation commit, the working tree contained only this report, its README link/QA status and the Portfolio terminology correction. All application changes were already pushed as `17ffd19`. The code reviewer did not modify the source. GitHub still reported `local-backend` passed and `ios` running for `17ffd19` at the final pre-commit inspection. The documentation push triggers a new PR-head check run; neither the old pending run nor local tests establish a pass for that new head. No merge, deployment, history rewrite or credential publication is authorized.

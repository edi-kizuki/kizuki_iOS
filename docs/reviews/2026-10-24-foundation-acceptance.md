---
title: Foundation acceptance specification and requirements-risk audit
created: 2026-10-24
updated: 2026-10-24
status: acceptance-specification-complete-for-round
baseline: f245fed081aee18da3ae0107b12590d5928e2ad7
implementation-branch: feature/ios-foundation (uncommitted, in progress)
reviewer: Claude Code Opus 5.5 (high), independent of Codex author
implementation-verdict: not-issued
---

# Foundation acceptance specification and requirements-risk audit

Related: [[AGENTS]], [[CLAUDE]], [[playbook]], [[00-what-exists]], [[2026-10-24-notion-source-extracts]], [[2026-10-24-ios-build-readiness]], [[2026-10-24-figma-screen-inventory]], [[2026-10-24-foundation-coding-report]], [[2026-10-24-foundation-spec]], [[0001-ios-foundation]].

## Round boundary

- This is acceptance criteria plus a requirements-risk audit. It is **not** PR approval.
- No implementation head SHA exists. Codex work is uncommitted on `feature/ios-foundation`. Observations below are against an unstable working tree and must be re-verified at the final SHA.
- Parent will commission a fresh independent review at the exact head SHA. That review issues the verdict.
- This round wrote only this file. No code, project, Git, remote, Supabase, or Notion mutations. No PR polling.
- Prior round (Codex tester, stopped) left a partial report. Its scope distinction and evidence ledger are preserved below. Its environment statements are superseded by user decisions (see next section).
- Prior Claude attempt failed on authentication before producing findings. This round ran under Claude authentication successfully; evidence is the file reads, code inspection, and findings recorded here.

## Confirmed decisions (supersede prior partial report)

- Native SwiftUI, iPhone only, iOS 17+. XcodeGen `project.yml`.
- Bundle identifier `club.kizuki.ios` — **confirmed**, not proposed.
- Supabase `enosggckdxjiaqtxalhg` — **production**. Development and automated tests target local Supabase only. Production migrations are a separate release step.
- Owner `edison@kizuki.club` — user-supplied; not independently verified here.
- Blobatar (https://blobatar.dev/) for profile pictures.
- Production-grade architecture, specs, meaningful tests, and real Supabase integration from the first prototype. Fixtures only for tests/previews.
- Figma = iterative visual guidance. Current Notion = behavior. Separate artwork exports are **not** a kickoff blocker.
- GitHub: `edi-kizuki` ADMIN; baseline `main` at `f245fed` pushed (parent-reported). Earlier 403 is resolved.

## Scope distinction (preserved)

The canonical [iOS MVP Build Plan](https://app.notion.com/p/40358cc06d1b811e9e83ff5fd2fdd7c0) defines M0 exit as a signed-in empty app that builds from CI and reads its own profile through RLS, with local migrations and RLS tests. SDK installation, compilation, or a session wrapper alone cannot prove M0.

This foundation PR can establish composition, configuration safety, real SDK integration, session contracts, avatars, and reproducible local tests. The PR must label milestone coverage as **partial M0** unless it also ships local migrations, RLS tests, and a CI build. Auth providers and onboarding are M1 unless delivered.

## Evidence ledger (this round)

- Read `AGENTS.md`, `CLAUDE.md`, [[playbook]], [[00-what-exists]], [[2026-10-24-ios-build-readiness]], [[2026-10-24-foundation-coding-report]], and the prior partial version of this file.
- Fetched via Notion connector (2026-10-24, pages marked `unverified` by Notion, no truncation flags): [Supabase Data Model & RLS](https://app.notion.com/p/40358cc06d1b8154a756dfd4733a5b81) (edited 16:32:03Z), [iOS Technical Architecture](https://app.notion.com/p/40358cc06d1b81f282a9c4b15f2f0ac6), [Backend Functions & Jobs](https://app.notion.com/p/40358cc06d1b81b8bbe2caefc10432ea), [iOS Build, Release & App Store Readiness](https://app.notion.com/p/40358cc06d1b8154b028cb6c0ab6790b), [Jev Integration (Parked)](https://app.notion.com/p/40358cc06d1b81ff98b3e4411eeaec7a).
- Inspected uncommitted working tree on `feature/ios-foundation`: `project.yml`, `.gitignore`, `ios/Configuration/*.xcconfig`, `ios/App/*`, `ios/Packages/KizukiKit/**`, `ios/UITests/*`, `scripts/avatars/*`.
- Verified read-only: `supabase-swift` tag `v2.55.4` exists on GitHub (`fee4bd78…`). npm `blobatar@2.7.0` is MIT, repo `github.com/Alain00/blobatar`. Local simulator runtimes: **iOS 26.0 only**; no iOS 17.x runtime.
- Not performed: builds, tests, simulator runs, Supabase calls, migrations, pushes, PR actions. No build/test result is asserted.

## Canonical requirements that bind the foundation

From the Notion pages above. Deviations need an ADR or explicit user decision.

- Swift 6, SwiftUI, iOS 17+, `@Observable`, async/await. Local Swift packages; one Xcode project.
- One `AppSession` listens to `supabase.auth.authStateChanges` and drives root (signed out → onboarding → main tabs).
- Repositories are protocols; tests swap fakes. No business rules in views.
- Sessions persist in Keychain (SDK default). App ships only project URL + publishable key. Service role key never in repo/app.
- Each scheme reads URL + publishable key from its own `.xcconfig`. **Production values never in Debug builds.**
- `profiles` (public): `id = auth.users.id`, `handle citext unique`, `display_handle`, `avatar_path`, … RLS: own row always readable.
- Avatars: Storage bucket `avatars` (public read, owner write, client-compressed ≤1024px). **Conflicts with Blobatar-only reading — see D1.**
- Unit tests use **Swift Testing**. UI tests cover onboarding paths later. **Every RLS policy has a pgTAP/SQL test** run by Supabase CLI.
- CI per PR: build + unit tests; local Supabase stack, migrations, RLS tests. **CI tool (Xcode Cloud vs GitHub Actions) is an open decision.**
- Repo layout: `supabase/migrations`, `supabase/functions`, `supabase/seed.sql`, `supabase/tests`.
- Environments table names `kizuki-staging` and `kizuki-prod`. User decision: `enosggckdxjiaqtxalhg` = production. Staging project does not exist/unknown.

## Acceptance criteria for the foundation PR

Legend: **M** = blocks merge of foundation PR. **M0** = blocks any "M0 complete" claim. **R** = blocks TestFlight/release, not this PR. Each needs the named evidence at the final head SHA.

### A. Project and reproducibility

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| A1 | `xcodegen generate` succeeds from clean checkout with pinned XcodeGen ≥2.46.0. No hand-edited `.pbxproj` committed. All `sources:` paths exist (`ios/Tests` currently missing). | Command log from clean clone | M |
| A2 | `Package.resolved` committed for the app workspace and survives `xcodegen generate`. All transitive SPM revisions pinned. | File in diff; `git status` clean after regenerate | M |
| A3 | CI and scripts resolve with `-onlyUsePackageVersionsFromResolvedFile` (or `-disableAutomaticPackageResolution`). | CI/script source | M |
| A4 | `supabase-swift` pinned `exact: 2.55.4` (tag verified). Any bump is a separate reviewed change. | `Package.swift` | M |
| A5 | Swift 6 language mode, `SWIFT_STRICT_CONCURRENCY=complete`, zero warnings in app + KizukiKit targets (or warnings listed and justified). | Build log | M |
| A6 | Deployment target 17.0 across project, targets, and package. No iOS 18+/26-only API without `#available`. | Build settings dump + grep | M |
| A7 | Runtime proof on an iOS 17.x simulator. Local host has iOS 26.0 runtime only. | Test run on 17.x **or** explicit "unverified on iOS 17 runtime" note in PR | M (note acceptable) / R (run required) |
| A8 | Avatar assets reproducible: `scripts/avatars` lockfile committed, exact `blobatar@2.7.0`, `sharp@0.35.5`; committed PNGs with SHA-256 manifest; `node_modules` not committed. | Diff, manifest, regenerate check | M |
| A9 | No secrets, private xcconfigs, `.env`, keys, or tokens in diff or history. | `git log -p` secret scan at head | M |

### B. Configuration fails closed and environments stay isolated

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| B1 | Debug builds cannot target production. Runtime guard rejects non-`local` env in DEBUG, and production URL/key never appear in Debug build settings or Info.plist. | Unit test on `AppConfiguration` + built Debug `Info.plist` inspected | M |
| B2 | Missing/empty/unexpanded (`$(`) URL or key → non-crashing configuration-error screen. No fallback to another environment. | Unit tests per field + UI or snapshot of error screen | M |
| B3 | Environment↔host binding enforced: local = `http`, loopback, port 54321; staging = https `*.supabase.co`, not production host; production = https `enosggckdxjiaqtxalhg.supabase.co` exactly. Userinfo, query, fragment, path rejected. | Table-driven unit tests incl. `localhost.evil.com`, `enosggckdxjiaqtxalhg.supabase.co.evil.com`, `https://127.0.0.1`, port override | M |
| B4 | Secret keys rejected: `sb_secret_*`, JWT `role: service_role`, malformed JWT. Accept `sb_publishable_*` and `role: anon`. | Unit tests | M |
| B5 | Release/Staging archives fail at **build time** if URL/key missing or mismatched. Runtime error screen alone lets a broken build ship. | Build-phase script or CI check + negative test | R (M if a Release CI job is added) |
| B6 | `NSAllowsLocalNetworking` absent from Staging/Release Info.plist. Currently unconditional in `ios/App/Info.plist`. | Built Release `Info.plist` | R (recommend fix in PR) |
| B7 | Automated tests cannot reach production. Unit tests use stub transport (`URLProtocol`) that fails any non-stubbed host. UI tests run only Debug. No scheme has a Test action on Staging/Release. CI never holds `Production.private.xcconfig`. | Test helper source; scheme dump; CI env | M |
| B8 | Keychain namespaces separated per environment and URL. Local/staging/prod bundle IDs (`.local`, `.staging`, base) produce separate keychains. | Unit test of `sessionStorageKey`; config review | M |
| B9 | `AppConfiguration` debug/log output redacts the key. No URL/key/token in user-facing errors. | Unit test | M |

### C. Session, Keychain, lifecycle, concurrency

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| C1 | One `AppSession` at root, `@MainActor @Observable`, subscribing once to `authStateChanges`. Re-entrant `observe()` is a no-op. Cancellation stops the SDK subscription. | Swift Testing with fake `SessionRepository` | M |
| C2 | Cold start states: no stored session → signed out; valid session → signed in + profile load; expired + refresh OK → signed in; expired + network failure → `unavailable` (keychain retained); revoked refresh token (`invalid_grant`) → signed out + keychain cleared. | Integration tests through real `SupabaseBackend` with stub transport + in-memory `AuthLocalStorage`, documenting SDK 2.55.4 behaviour with `emitLocalSessionAsInitialSession: false` | M |
| C3 | `unavailable` has a recovery path without relaunch (retry or automatic on foreground/refresh). Current copy says "reopen Kizuki". | Test or documented limitation | M (documented limitation acceptable) |
| C4 | Token refresh / `userUpdated` for the same user does not reset UI or reload profile. User switch reloads and cancels stale load. | Unit tests incl. generation guard race | M |
| C5 | Stale profile response after sign-out or user switch never renders. | Unit test with delayed fake | M |
| C6 | Sign-out uses `.local` scope; clears Keychain session; UI returns to signed out. Offline sign-out: local session removed, UI signed out, no contradictory "Couldn't sign out". Double-tap guarded. | Integration test with stub transport (offline + 200 + 401) | M |
| C7 | Keychain accessibility class verified (expect `AfterFirstUnlock[ThisDeviceOnly]` so background refresh works and tokens don't migrate via backup). | SDK source citation at 2.55.4 or custom storage + test | M |
| C8 | Foreground/background: auto-refresh stops on background, resumes on foreground; session valid after >1h background. | SDK source citation + manual simulator note, or test | R (citation M) |
| C9 | Reinstall policy: Keychain survives app deletion on iOS. Decide whether first launch after reinstall clears stale session. | Decision recorded (see D4) | M (decision), R (impl) |
| C10 | `--ui-testing` fixture backend compiled only under `DEBUG`. Staging/Release binaries contain no fixture symbols. | `#if DEBUG` review + `nm`/strings on Release build | M |
| C11 | Profile fetch re-validates session and rejects identity mismatch. Client UUID never treated as authorization. | Unit/integration test | M |

### D. Real Supabase integration (local only)

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| D-1 | `supabase/` initialized (`config.toml`, migrations). `profiles` migration matches Notion: `id` FK `auth.users` on delete cascade, `handle citext unique`, `display_handle`, `avatar_path`, timestamps, RLS enabled. | Migration files; `supabase db reset` log | M0 |
| D-2 | RLS tests: own row readable; other user's undiscoverable/incomplete row denied; blocked denied (if `blocks` exists); anon denied; owner-only update. | pgTAP/SQL tests run by Supabase CLI | M0 |
| D-3 | Opt-in local integration test: sign in a seeded local user, read own profile through `SupabaseBackend`, assert denial for another id. Hard guard: aborts unless URL host is loopback. | Test source + run log against `supabase start` | M0 (M if PR claims "real Supabase integration") |
| D-4 | Column projection `id,handle,display_handle,avatar_path` decodes against migrated schema. | D-3 run | M0 |
| D-5 | No production migrations, dashboard edits, or production auth config changes in this PR. | Diff + parent confirmation | M |
| D-6 | If D-1..D-3 are deferred, PR title/body says **partial M0**, lists them as follow-ups, and does not claim end-to-end Supabase verification. | PR body | M |

### E. Blobatar avatars

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| E1 | No runtime network to `blobatar.dev`. Seeds sent to the hosted endpoint would leak identifiers to a third party. | grep + network stub | M |
| E2 | Avatar choice uses only opaque profile UUID; never handle, email, or name. Deterministic across launches and devices. | Unit test of `AvatarCatalog` mapping stability (golden values) | M |
| E3 | All 32 resources load from `Bundle.module`; fallback renders if missing. | Unit test enumerating `0..<32` | M |
| E4 | MIT notice for Blobatar retained (bundled `Blobatar-LICENSE.txt`). Third-party acknowledgements screen planned. sharp/libvips (Apache-2.0/LGPL-3.0) are build-time only, not shipped. | File + note | M (notice) / R (acks screen) |
| E5 | Avatar marked decorative (`accessibilityHidden`) or labelled consistently. | Code review | M |
| E6 | Behaviour with `avatar_path` (user upload) defined. Currently ignored. | Decision D1 | M (decision recorded) |

### F. UI, accessibility, design

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| F1 | Root states rendered: restoring, signed out, unavailable, signed-in loading/missing/failed/loaded, config error, sign-out error. | Simulator screenshots per state via launch-argument router | M |
| F2 | Dynamic Type at AX5 without truncation; VoiceOver labels; 44×44pt targets; Reduce Motion respected. | XCUITest at AX size + screenshots | M |
| F3 | UI tests target accessibility identifiers, not copy with embedded newlines. | Test source | M (recommend) |
| F4 | Forced dark mode (`.preferredColorScheme(.dark)`) and system fonts are provisional; noted against Figma/UI-UX spec. | PR note | M (note) |
| F5 | No navigation shell implying the disputed Figma tab set. | Code review | M |

### G. Tests and CI

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| G1 | Unit tests in Swift Testing per canonical spec (XCTest only for UI tests). | Test source | M |
| G2 | Tests assert behaviour, not implementation trivia. Each B/C/E criterion above maps to ≥1 test. Coverage reported for KizukiCore and KizukiInfrastructure. | Traceability table in PR; `xccov` report | M |
| G3 | `xcodebuild test` on `Kizuki-Local` passes locally with result bundle path, simulator name/OS, Xcode version. | `.xcresult` summary | M |
| G4 | CI workflow runs generate → resolve (pinned) → build → unit + UI tests, unsigned, no secrets. CI tool choice confirmed by user (Notion lists it as open). | Workflow file + green run URL at head SHA | M (run) / decision D3 |
| G5 | CI pins Xcode version compatible with Swift 6 and the project; runner image documented. | Workflow file | M |
| G6 | Supabase CLI job (migrations + RLS tests) in CI once `supabase/` exists. | Workflow file + run | M0 |

### H. Documentation and process

| ID | Criterion | Evidence | Level |
| --- | --- | --- | --- |
| H1 | ADR `0001-ios-foundation` and `2026-10-24-foundation-spec` exist (referenced by coding report; `docs/adrs` and `docs/specs` currently empty). Record single `KizukiKit` package vs Notion's `Packages/Core|DesignSystem|Features` layout. | Files in diff | M |
| H2 | Coding report states verification actually run, with commands and results; no production-readiness claim. | `docs/lanes/2026-10-24-foundation-coding-report.md` | M |
| H3 | Coding report updated: environment and bundle ID are **confirmed** (report still says "remain open"). | Diff | M |
| H4 | New notes link related notes with `[[wikilinks]]`. | Diff | M |
| H5 | Author ≠ reviewer. Final verdict from fresh independent review at exact head SHA. | PR thread | M |

## Requirements-risk audit of the in-progress tree

Observed on uncommitted files. Not findings against a PR. Re-verify at head SHA.

### Positive observations

- `AppConfiguration` binds environment to host, rejects userinfo/query/path, rejects secret/service-role keys, redacts key in `debugDescription`.
- DEBUG guard forces `local` environment; fixture backend gated by `#if DEBUG` and `--ui-testing`.
- Separate bundle IDs and Keychain storage keys per environment. PKCE flow. `signOut(scope: .local)`.
- `AppSession` uses generation counter and cancellation to drop stale profile loads. Profile read re-checks session identity.
- Avatars generated offline from opaque preset seeds; no runtime third-party call; MIT notice bundled.
- `.gitignore` excludes private xcconfigs, `.env*`, `node_modules`, Supabase temp dirs.

### Risks to resolve or document

| # | Risk | Where | Ask |
| --- | --- | --- | --- |
| R1 | `ios/Tests` referenced by `project.yml` but absent; no package tests yet. Generation or test plan will fail. | `project.yml` | A1, G1–G3 |
| R2 | No `Package.resolved`; transitive SDK deps unpinned. | repo | A2, A3 |
| R3 | No `supabase/` dir, migrations, or RLS tests. Production public schema is empty, so `profiles` read cannot be exercised anywhere yet. | repo | D-1..D-6 |
| R4 | No sign-in path. Signed-in state reachable only through DEBUG fixtures. "Real Supabase integration" currently means client construction + session restore. | `KizukiApp.swift` | D-3, D-6 |
| R5 | `NSAllowsLocalNetworking` shipped in Release/Staging Info.plist. | `ios/App/Info.plist` | B6 |
| R6 | Missing Release key yields runtime "Setup needed" screen telling users to "Add local backend configuration". Wrong copy for production; build should fail first. | `FoundationRoot.swift`, xcconfigs | B5 |
| R7 | SDK offline/expired-token behaviour with `emitLocalSessionAsInitialSession: false` unverified; `.unavailable` has no in-app recovery. | `SupabaseBackend.events()`, `FoundationRoot` | C2, C3 |
| R8 | SDK may clear local session before the network logout call; an offline sign-out then sets `signOutFailed` while SDK already emitted signed-out. | `AppSession.signOut()` | C6 |
| R9 | `KeychainLocalStorage` accessibility class and reinstall persistence not established. | `SupabaseBackend.init` | C7, C9 |
| R10 | `.missing` profile shown as error + retry. Spec root goes signed out → **onboarding** → tabs; a new user without a row is expected, not a failure. | `FoundationRoot` | D2 decision |
| R11 | 32 preset avatars → frequent collisions (≈50% chance two of 7 users share one). Not per-user unique as Blobatar normally is. `avatar_path` ignored. | `AvatarCatalog` | D1 |
| R12 | sharp/libvips rasterization may differ across versions/platforms; regenerated PNGs may not be byte-identical. | `scripts/avatars` | A8 manifest |
| R13 | iOS 17 runtime absent; Xcode 26 only. Swift 6 + Xcode 26 CI runner availability unverified. | host, CI | A7, G5 |
| R14 | UI tests match copy text incl. `\n`; brittle. | `FoundationUITests.swift` | F3 |
| R15 | Unit tests must be Swift Testing per spec; none exist yet. | — | G1 |
| R16 | Coding report says environment and bundle ID "remain open"; both confirmed. | coding report | H3 |
| R17 | Notion environments name `kizuki-staging`/`kizuki-prod`; user designates `enosggckdxjiaqtxalhg` production. Staging project absent; Staging config fails closed (empty URL) — correct. | Notion vs repo | D5 |

### Release-only items (not foundation blockers)

Privacy manifest for app + SDKs, App Privacy answers, account deletion (`delete-account`), report/block on UGC, terms/privacy URLs, 18+ age rating, Sign in with Apple alongside Google, crash reporting choice, third-party acknowledgements, signing/App Store Connect record. Track as **R**; do not block this PR.

## Decisions needed from the user

| ID | Decision | Why it matters |
| --- | --- | --- |
| D1 | Blobatar role: default/fallback when `avatar_path` is empty (spec has `avatars` Storage bucket and Figma photo-upload states), or sole avatar system? Per-user unique (in-process render or server-generated PNG keyed by opaque id) vs 32 bundled presets? | Determines E6, R11, Storage work. Native Swift has no Blobatar port; per-user in-app rendering needs SVG rasterization (WebKit/JavaScriptCore or a Swift port) or server generation. Hosted `https://blobatar.dev/avatar/<name>` exists per README but sends seeds to a third party; not acceptable for user identifiers without a privacy review. |
| D2 | Foundation behaviour for signed-in user with no `profiles` row: onboarding placeholder vs error. Who creates the row (trigger on `auth.users` vs `set_handle`)? | R10, D-1 migration design |
| D3 | CI tool: GitHub Actions vs Xcode Cloud. Notion marks it open. | G4 |
| D4 | Clear stale Keychain session on first launch after reinstall? | C9; privacy expectation on shared/resold devices |
| D5 | Staging project: create `kizuki-staging`, or no staging until later? Confirm `enosggckdxjiaqtxalhg` is the Notion `kizuki-prod`. | B3 staging rules, release flow |
| D6 | Is a minimal local-only sign-in (seeded email user) in scope for this PR to prove D-3, or deferred to M1? | Determines whether PR can claim real integration |

## Unresolved items carried forward

- Implementation incomplete; no head SHA; no build/test evidence exists. **No verdict issued.**
- Prior Codex tester round: partial report only; no findings beyond scope/evidence sections (preserved above). No prior Claude findings exist (auth failure).
- Figma illustrations file still MCP-blocked (edit access). Not a kickoff blocker.
- Navigation, Start destination, compensation-rule contradictions in [[00-what-exists]] remain open; foundation must not encode them (F5).
- Notion pages are `unverified` by Notion's own field; treated as current specifications, not approval proof.
- Owner `edison@kizuki.club` not verified against Supabase org membership in this round.

## Exact blockers for merge (current tree)

1. A1/R1 — `ios/Tests` missing; generation/test plan incomplete.
2. A2/A3/R2 — `Package.resolved` not committed; resolution not pinned in CI.
3. G1–G3/R15 — no unit tests; no local `xcodebuild test` evidence.
4. G4/G5 — no CI workflow or green run at head SHA; CI tool decision D3 open.
5. B7 — no stub-transport guard proving tests cannot reach production.
6. C2/C6/C7 — session restore, sign-out, and Keychain accessibility behaviour unverified against SDK 2.55.4.
7. H1/H3 — ADR and spec missing; coding report states confirmed decisions as open.
8. D-6 — PR must label **partial M0** unless D-1..D-3 ship.
9. D1/D2 — avatar and missing-profile decisions recorded (decision, not implementation, blocks merge).

Exact blockers for an **M0** claim: D-1, D-2, D-3, D-4, G6.

## Next review

Parent commissions fresh independent review at exact head SHA. Reviewer receives this criteria list, the PR diff, and CI/test artifacts — not the author's reasoning.

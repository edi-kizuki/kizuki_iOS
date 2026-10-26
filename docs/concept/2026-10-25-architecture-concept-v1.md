---
title: Kizuki v0 architecture concept v1
created: 2026-10-25
version: 1
tags: [project/kizuki, architecture-round, concept, ios, supabase]
status: draft-for-independent-review
---

# Kizuki v0 architecture concept v1

Related: [[playbook]], [[2026-10-24-architecture-round-1-interview]], [[2026-10-25-supabase-backend-research]], [[2026-10-25-ios-client-integrations-research]], [[2026-10-25-figma-full-walkthrough]], [[2026-10-25-wayfinder-map]]

Also: [[2026-10-25-notion-technical-extracts]], [[2026-10-24-notion-source-extracts]], [[00-what-exists]]. Map ticket: `docs/map/tickets/010-architecture-concept.md`.

**How to read this.** Each section starts in plain language, then gives technical detail. `D#` = locked user decision # in [[2026-10-24-architecture-round-1-interview]]. `AD:` = agent default in the same file (user may override). `N-DM`, `N-BF`, `N-ALG`, `N-ARCH`, `N-RS`, `N-TS` = Notion pages Data Model & RLS, Backend Functions & Jobs, Recommendation & Taste Algorithm v1, iOS Technical Architecture, Recommendation System, Trust & Safety (extracts in [[2026-10-25-notion-technical-extracts]]). `R-BE §x` = [[2026-10-25-supabase-backend-research]]; `R-IOS §x` = [[2026-10-25-ios-client-integrations-research]]; `FIG` = [[2026-10-25-figma-full-walkthrough]]; `N-ONB` = Onboarding Spec v3.1 in [[2026-10-24-notion-source-extracts]]. **[unverified]** marks claims not confirmed against a primary source or running system. **[design]** marks my recommendation, not a fact.

Precedence used throughout: locked decisions and agent defaults → Notion → research lanes → Figma. Every place they disagree is logged in Appendix A.

Late inputs applied (2026-10-25): D37 (canonical Figma = copies `nPqXTMCtd3OVZTSU7Y2uN3` app, `dPirB4bC1bB7KcxaacOVHG` illustrations; node IDs cited from [[2026-10-25-figma-full-walkthrough]] refer to the original `XIe9K1RrE3wgLnlBJ59p1i` and are assumed to carry over to the copy **[unverified]**), D38 (staging project `ankgfqkgflcalmlreetu` exists), D39 (Apple Developer enrolment deferred: TestFlight distribution, Sign in with Apple on device, and APNs are blocked on it). Figma variables now exist but this concept still chooses no colours or fonts; a separate visual pass owns tokens.

## The one-line recommendation

Build v0 as **one native SwiftUI app (per-tab feature modules over a shared Core, fixtures first) on one Supabase schema where every rule that protects a user lives in Postgres** (RLS + `security definer` RPCs + triggers, all pgTAP-tested), with exactly three Edge Functions (`delete-account`, `send-push`, `tmdb-proxy`), Postgres Changes for chat, and a SQL `recommend` RPC that implements Notion's v1 scoring formula without pgvector. Run it against the **staging** Supabase project `ankgfqkgflcalmlreetu` seeded with fictional data, and ship to TestFlight once the deferred Apple Developer enrolment happens (D38, D39). Build it as 19 small tracer-bullet slices, core loop first.

What I am least sure of (detail in section 7): whether v0 is too big for a "ship when it works" solo build (19 slices); what "Matches" in the Suki tab means; and whether Supabase's email-confirmation behaviour supports the verify-by-code flow I recommend.

---

## 1. Problem, users, v0 destination

### Plain language

Creative people (filmmakers, musicians, visual artists, mixed-practice creators) struggle to find collaborators whose taste and working conditions actually fit. Kizuki shows each person a small set of people and projects that fit both ways, explains why, and lets them send a request. Chat opens only when the other person accepts. That accepted request is the product's unit of success.

v0 proves that loop on an iPhone, end to end, with fictional data, in TestFlight.

### Detail

- **Problem and promise.** "Find your people. Make something real." Kizuki matches on capability, taste, intent, availability, work mode/city, compensation and trust (`00-what-exists` "What the app is"; Canonical Product Brief in `2026-10-24-notion-source-extracts`).
- **Users.** Individual creators only in MVP; collectives and businesses later (Product Requirements "User types", via `00-what-exists`). First cohort: Berlin indie filmmakers and the collaborators their projects need; not a film-only boundary (same source). Adults only, 18+ (`N-TS` "Minors"; AD: age gate).
- **Core loop (product).** Identity and intent → relevant people/projects → understandable reasons → contextual request → acceptance and conversation → completed collaboration → Made Together (Canonical Product Brief). v0 stops at conversation; Made Together is out (interview "Out of v0").
- **North star.** Confirmed meaningful collaborations per monthly active creator (`00-what-exists`). Not measurable in v0 (no real users, D18); v0's proxy is "the loop works end to end".
- **v0 destination (map).** "Core loop v0 working end to end on mock data, native iOS on TestFlight: sign in (Apple or email) → onboarding (incl. taste cards) → Home feed → request → accept → chat, plus Search, Suki, My Projects and Profile. No target date; ship when it works." ([[2026-10-25-wayfinder-map]] "Destination"; D1, D18, D19, D21, D29).
- **Constraints that shape everything.**
  - Native iOS 17+, Swift 6 strict concurrency, SwiftUI, Observation (repo `project.yml`; `N-ARCH` Stack).
  - Supabase. Production `enosggckdxjiaqtxalhg` is untouched; TestFlight runs on staging `ankgfqkgflcalmlreetu` with mock data only (D10, D29, D38). TestFlight itself waits on Apple Developer enrolment, deferred by the user (D39).
  - Five tabs: Home, Search, Suki, My Projects, Profile; Inbox and Settings are icons in Home's top bar; system `TabView`, icon-only (D19, D32).
  - Chat only after an accepted request; requests go both ways (join and invite) (D11, D36).
  - No payments, follows, comments, events, Google sign-in, Made Together, appeals tooling (D12, D13, D24, D25; interview "Out of v0").
- **Where the build starts.** A working foundation exists: KizukiKit with `KizukiCore` (`AppConfiguration`, `AppSession`, `Profile`, `SessionRepository`/`ProfileRepository`), `KizukiInfrastructure` (`SupabaseBackend`, supabase-swift pinned `exact: 2.55.4`), `KizukiDesignSystem` (Blobatar avatars), `KizukiFoundationFeature`; three xcconfig environments; one migration (`profiles`, `profile_settings`, provisioning trigger) with 10 pgTAP tests; CI with an iOS job (`macos-15`, Xcode 26.0.1) and a Docker-backed `local-backend` job (repo files `ios/Packages/KizukiKit/Package.swift`, `supabase/migrations/20261024000100_own_profile_foundation.sql`, `.github/workflows/foundation.yml`; `R-BE §0`, `R-IOS §1.1`).

---

## 2. Recommended design, end to end

### 2.0 Plain language

- **The app** is a set of small feature modules, one per tab, that only talk to "repositories" (interfaces). In tests and previews the repositories return invented data; in the real app they call Supabase. This lets screens be built and reviewed before the backend exists.
- **The backend is the rulebook.** Who can see what, who can message whom, what a block hides, how a request changes state: all enforced inside the database, so a buggy or hostile app cannot bypass them.
- **Three small server functions** handle what the database cannot: deleting an account (needs admin rights), sending push notifications (needs Apple's key), and searching films (keeps the TMDB key off the phone).
- **Matching is a transparent formula** in the database. It scores fit in both directions, hides anything blocked or incompatible, and returns 2–4 plain reasons. No AI model.
- **Chat** uses a live database feed for new messages, but the messages table is always the source of truth.

### 2.1 System overview

```
iPhone app (SwiftUI)
  ├─ Supabase Auth ─────── Apple ID token / email + password
  ├─ PostgREST (RLS) ───── reads + own-row writes
  ├─ RPC (security definer) ─ state changes: requests, publish, block, report, onboarding, recommend
  ├─ Realtime (Postgres Changes on messages, filtered by conversation_id)
  ├─ Storage ───────────── avatars (public), collab-photos + project-covers (private, signed URLs), taste-cards (public, read-only)
  ├─ Edge Function tmdb-proxy ──► TMDB API
  ├─ Edge Function delete-account ──► Storage API + auth.admin.deleteUser
  └─ MusicBrainz (direct from device, 1 req/s queue)
Postgres triggers ──► notification_outbox ──(Database Webhook)──► Edge Function send-push ──► APNs
pg_cron ──► expire projects (hourly), expire requests (daily)
```

Rule of thumb, adopted from `N-ARCH` "System overview": the app reads through RLS and writes only its own rows directly; anything that touches another user, ranks candidates, calls an external service or enforces limits goes through an RPC or an Edge Function.

### 2.2 iOS client

**Modules** (one Swift package, many targets; extends `R-IOS §1.3`, trimmed to 7 feature targets as that section's "cheaper variant" allows):

| Target | Owns | Depends on |
|---|---|---|
| `KizukiCore` (exists) | Domain models, repository protocols, `AppSession`, `AppRoute`, `AppTab`, request/project state enums, error codes | — |
| `KizukiInfrastructure` (exists) | `Supabase*Repository` implementations, `ChatTransport` (Postgres Changes), storage uploader, TMDB/MusicBrainz clients | Core, supabase-swift 2.55.4 |
| `KizukiPlatform` (new) | `LocationService` (one-shot, reduced accuracy), `NotificationService` (permission, APNs token), `DeepLinkParser`, permission-primer state | Core |
| `KizukiDesignSystem` (exists) | Tokens (placeholder until design round), components (cards, chips, tiles, sheets, `RemoteImage`), `ProfileAvatar` + Blobatar | — |
| `KizukiEmbeds` (new) | URL → embed descriptor (pure, allow-list), facade card, locked-down `WKWebView` player | DesignSystem |
| `KizukiTestSupport` (new) | Fixture data (one shared invented dataset), fake repositories; never linked into Release | Core |
| `KizukiEntryFeature` | Sign-in, email sign-up + code verify, handle, terms/18+, onboarding steps, permission primers, taste cards, favourites picker | Core, DesignSystem, Platform |
| `KizukiHomeFeature` | Feed (projects + people), "Finish your project" card, project detail, person card, Inbox list + chat screen | Core, DesignSystem |
| `KizukiSearchFeature` | Search bar, chips, 3-column grid, post viewer | Core, DesignSystem |
| `KizukiSukiFeature` | Matches, requests (in/out), request detail, request composer, create chooser (project / post a collab) | Core, DesignSystem |
| `KizukiMyProjectsFeature` | Drafts / Published / Past lists, project editor, publish, close, invite | Core, DesignSystem |
| `KizukiProfileFeature` | Own + other profile, profile edit, links/embeds, favourites display | Core, DesignSystem, Embeds |
| `KizukiAccountFeature` | Settings, report sheet, block, blocked list, delete account, legal/support | Core, DesignSystem |

Rules [design, from `R-IOS §1.3`]: features never import `KizukiInfrastructure` or each other; the App target is the only composition root. Inbox/chat sits in Home because its entry point is the Home top bar (D19); if it grows, it splits into its own target without changing other features.

**Routing.** `TabView(selection:)` with `.tabItem` + `.tag` (iOS 17 floor; the `Tab {}` API is iOS 18+, `R-IOS §1.5`), icon-only system tab bar (D32). One `NavigationStack(path:)` per tab. `@MainActor @Observable AppRouter { selectedTab; paths[AppTab] }` with `open(_ route: AppRoute)`. `AppRoute` lives in Core: `.profile(UUID)`, `.project(UUID)`, `.request(UUID)`, `.conversation(UUID)`, `.inbox`, `.settings`, `.collabPhoto(UUID)`, `.report(ReportTarget)`. Each tab registers one `navigationDestination(for: AppRoute.self)` supplied by the App target, which breaks cross-feature import cycles (`R-IOS §1.5`). Entry points: `kizuki://` custom scheme via `onOpenURL`; push tap maps `userInfo["route"]` to `AppRoute`. Universal Links deferred (no domain decided, `R-IOS §1.5`). A launch-argument router (`-screen <id> -fixture <name>`) opens any screen directly for screenshot galleries ([[playbook]] §7).

**Root state.** Existing `AppSession` (generation-guarded, `R-IOS §1.2`) drives root: `restoring → signedOut → signedIn(profile)`. Add a derived `rootPhase`: `entry` (signed out) / `verifyEmail` / `onboarding(step)` / `main`. `onboarding_completed_at` null → onboarding; resume at the first unanswered step from `profile_settings.onboarding_state` (`N-ARCH` "Onboarding implementation"; `N-ONB` Auth 1).

**DI.** One `Dependencies` struct of protocol-typed repositories, built in the App target (`Live` or `Fixture` by launch argument / build config), injected via SwiftUI environment; models receive what they need through `init` (`R-IOS §1.4`).

**State.** Observation only. Per screen: `@MainActor @Observable final class XModel` owned by the view with `@State`; one `LoadState<T>` enum (`loading/loaded/empty/failed`) per async load. No TCA, no SwiftData, no offline queue (`R-IOS §1.4`, `§1.7`). Images: one `RemoteImage` on a configured `URLCache`, keyed by storage object path, not by signed URL (`R-BE §5.1`).

**Errors.** Server returns typed codes from `N-BF` "Error codes": `unauthenticated`, `email_not_verified`, `missing_fields(fields)`, `blocked`, `duplicate_request`, `rate_limited(retry_after)`, `not_found`, `validation_failed(fields)`, `server_error`. Core maps them to one `KizukiError` enum; RPCs raise them as Postgres exceptions with a fixed `errcode`/`detail` JSON [design].

**Fix before feature work** (`R-IOS §1.2`): move `UITestBackend` out of `KizukiApp.swift` into `KizukiTestSupport`; remove the global `.preferredColorScheme(.dark)`; add purpose strings, `ITSAppUsesNonExemptEncryption`, `PrivacyInfo.xcprivacy`, entitlements (Sign in with Apple, Push).

### 2.3 Supabase: schema, RLS, RPCs, Edge Functions

Full table list in section 4. Principles (`N-DM` Conventions; `R-BE §1.1`):

1. RLS on every public table, no exceptions; a table without policies is unreadable.
2. Public and private data in separate tables (`profiles` vs `profile_settings`), never hidden columns.
3. Clients write their own simple rows directly (profile fields, links, feedback, drafts). Every **state machine** (requests, project status, conversations, blocks, reports, onboarding completion) changes only through `security definer` RPCs with `set search_path = ''`, `revoke all from public, anon`, `grant execute to authenticated`. Clients have no UPDATE grant on those tables.
4. Business rules that must hold even for a buggy client are CHECK constraints, partial unique indexes and triggers too, not only RPC code (`R-BE §1.1` item 7).
5. One `private.is_blocked(a uuid, b uuid)` (security definer, in the unexposed `private` schema) used by a **restrictive** policy on every user-content table, so "block hides both ways" cannot drift (`N-DM` "A shared SQL function is_blocked(a, b)…"; mechanics `R-BE §1.10`).
6. Every policy `to authenticated`, `(select auth.uid())` wrapped, every filtered column indexed (`R-BE §1.1` item 3).

**RPCs (v0).** Notion lists `send-request`, `respond-request`, `publish-project`, `complete-onboarding` as Edge Functions (`N-BF`). I recommend SQL RPCs instead: they run in one transaction with the state change, are pgTAP-testable offline, need no service role and no Deno deploy path, and push still fires from a trigger (see 2.6). Logged in Appendix A.

| RPC | Purpose | Key checks |
|---|---|---|
| `handle_available(text)` | Debounced availability | Format 3–20 (AD), reserved list; 30/min rate limit (`N-BF`) |
| `set_handle(text)` | Claim handle | Same; rename rules deferred (AD) |
| `accept_terms(terms_version, privacy_version, age_confirmed)` | 18+ gate + Terms, server timestamp | `age_confirmed` must be true (AD; `N-ONB` Auth 3) |
| `save_onboarding_step(step, payload)` | Save after every step | Per-step payload validation (`N-BF`) |
| `complete_onboarding()` | Finish onboarding | Required fields per `N-ONB` data contract "Browse"; writes taste facets; creates Start draft; sets `onboarding_completed_at` |
| `submit_taste(selections, pairwise)` | Atomic taste write | 3–5 selections, ≥3 pairwise; applies `N-ALG` update rules |
| `publish_project(id)` / `close_project(id, reason)` / `reopen_project(id)` | Project state machine | Publish contract (section 4.3) |
| `send_request(kind, recipient, project_id?, project_role_id?, idea_text?, message)` | New request or invite | Verified email, completed onboarding, primary role, no block, no duplicate, project published + role open, compensation filter, 5/day (<7-day account) or 20/day (`N-BF` rate limits) |
| `respond_request(id, accept bool, decline_reason?)` | Accept/decline | Caller is recipient; pending; on accept: conversation + participants + `project_members` + role filled |
| `withdraw_request(id)` | Sender withdraws | Caller is sender; pending |
| `recommend(surface, limit)` | Ranked IDs + band + reason codes | Section 2.8 |
| `block_user(id)` / `unblock_user(id)` | Block both ways | Side effects in 2.9 |
| `submit_report(subject_type, subject_id, category, context)` | Report | 10/day (`N-BF`); snapshot; auto-hide trigger |
| `record_feedback(target_type, target_id, kind)` | Like/save/hide/not my style | Own rows |
| `register_device_token(token, environment)` | Push token | Own rows |

**Edge Functions (v0): exactly three.**

| Function | Why not SQL | Contract |
|---|---|---|
| `delete-account` | Needs service role: Storage API object removal and `auth.admin.deleteUser` (`R-BE §4.4`) | POST with user JWT → verifies JWT → removes `avatars/<uid>/`, `collab-photos/<uid>/`, `project-covers/<uid>/` via Storage API → anonymises/cascades per 4.5 → `auth.admin.deleteUser(uid)` → 200. Idempotent. Client then `signOut(scope: .local)` |
| `send-push` | Needs APNs `.p8` key and HTTP/2 to APNs | Invoked by Database Webhook on `notification_outbox` insert; looks up `device_tokens`; sends; deletes tokens APNs reports invalid (`N-BF` send-push); marks outbox row sent/failed |
| `tmdb-proxy` | TMDB key must not ship in the binary (`R-IOS §6.1`) | GET `/search?q=` and `/movie/{id}` with user JWT; per-user throttle; returns id, title, year, poster path only; short cache |

Not in v0 (from `N-BF`): `recommendations` (replaced by SQL RPC, D15), `validate-link` and `recheck-links` (client + DB allow-list instead; `R-BE §1.7`), `track` (no analytics in v0), `export-account` (launch blocker, not TestFlight blocker), `propose/confirm-completion` (Made Together out).

**Scheduled jobs (pg_cron).** `expire-projects` hourly: published past `expires_at` → `past` / `expired`. `expire-requests` daily: pending older than 14 days → `expired` (`N-BF` scheduled jobs). Reads also filter `expires_at > now()` so a missed job cannot show stale items (`R-BE §2.6`). Deferred: `recheck-links`, `project-draft-reminder`, `purge-deleted`, `refresh-taste-vectors`.

### 2.4 Realtime chat

- **Transport: Postgres Changes** on `public.messages`, filter `conversation_id=eq.<id>`, one channel per open chat, plus one Inbox refresh on foreground. RLS on `messages` is the single authorization truth and is re-checked per event; Broadcast authorization is cached until JWT expiry, so a block would not apply immediately (`R-BE §3.1–3.3`). Free plan limits (200 concurrent connections, 100 msg/s) are far above v0 needs (`R-BE §3.2`).
- **Source of truth is the table.** On subscribe, reconnect and app foreground: fetch `created_at > last_seen`. Realtime is a nudge (`R-BE §3.1`).
- **Send:** PostgREST insert with client-generated `client_id` (unique per sender) for idempotent retry. Never client Broadcast (it would bypass the INSERT policy) (`R-BE §3.2`).
- **Swap seam:** `ChatTransport` protocol in Core (`messages(in:since:)`, `send(...)`, `updates(for:) -> AsyncStream`). Moving to Broadcast-from-DB later is a trigger + policy + new transport, schema unchanged (`R-BE §3.2`).
- SDK: `supabase.channel(...)`, register `postgresChange(InsertAction.self, schema:table:filter:)` before `subscribeWithError()`; shared client so refreshed tokens reach Realtime (verified in 2.55.4 source, `R-BE §3.4`).
- **v0 scope:** direct conversations only, one per pair (reused if a pair already has one), text only, 1–2000 chars, no edit, no unsend, no attachments, no group chat (open decision OD-2). Project context pinned in the header (Product Requirements "Messaging requirements").

### 2.5 Storage

| Bucket | Visibility | Path | Writer | Limit |
|---|---|---|---|---|
| `avatars` | public, not listable | `<uid>/<uuid>.jpg` (new name per change) | owner | 1 MB, jpeg/webp |
| `collab-photos` | private, signed URLs ~1 h | `<uid>/<photo_id>/thumb.jpg`, `full.jpg` | owner | 2 MB, jpeg |
| `project-covers` | private, signed URLs | `<uid>/<project_id>/<uuid>.jpg` | owner | 2 MB, jpeg |
| `taste-cards` | public, read-only | `<realm>/<slug>.jpg` | seed/migration only | 1 MB |

Source: `R-BE §5.1`. Private buckets make block, hide and moderation removal effective on reads; avatars stay public because Blobatar covers absence (D9) and names are random. No upsert (so no UPDATE policy). Client makes two renditions (≈400 px thumb, ≈1600 px full), converts HEIC → JPEG, strips EXIF/GPS before upload; no dependency on server image transforms (Pro-only, vendor claim) (`R-BE §5.3`). `N-ARCH` says compress avatars to max 1024 px; adopted for avatars. Deleting a row never deletes its object; always Storage API remove first (`R-BE §5.2`). Local `config.toml` has `[storage] enabled = false`; enabling is part of slice B2.

### 2.6 Auth

- **Methods:** Sign in with Apple + email/password (D13, D30). Google later (D13).
- **Apple:** native `ASAuthorizationAppleIDCredential`, random nonce (SHA-256 hex into the request, raw into `OpenIDConnectCredentials.nonce`), `signInWithIdToken(.apple)`; bundle ID registered under the Apple provider's Client IDs; no Services ID or secret rotation for native-only (`R-BE §4.1`). Save full name only on first authorization and only if the user confirms (`R-BE §4.1`). Apple sign-in runs on Staging/Production builds; Local (Debug, `club.kizuki.ios.local`) uses seeded email users unless that App ID is registered (`R-IOS §1.2`, `§8.1` item 4). Registering the App ID with the Sign in with Apple capability needs the Apple Developer account, deferred by D39; until then email/password is the only working method on every environment.
- **Email:** `signUp(email, password)`, 10+ chars, leaked-password protection (`N-ARCH` Auth; `N-ONB` Auth 1). Leaked-password protection plan availability **[unverified]**. Verification: **6-digit code entered in-app** (confirm-signup template with `{{ .Token }}`, `verifyOTP(type: .signup)`) right after sign-up, before onboarding (OD-3). Avoids universal links and in-app-browser breakage (`R-BE §4.2`). Behaviour with `enable_confirmations = true` **[unverified]** (`R-BE §4.2`, §7.3).
- **SMTP:** built-in mailer sends 2 emails/hour/project; staging needs custom SMTP and a sending domain before any tester signs up (`R-BE §4.2`).
- **Session:** existing PKCE + Keychain + per-environment storage key; `signOut(scope: .local)` (repo `SupabaseBackend.swift`). JWT expiry 3600 s locally (`config.toml`).
- **Never merge accounts silently** (`N-ONB` Auth 1). Check Supabase identity auto-linking settings before staging **[unverified]** (`R-BE §4.2`).
- **App Review demo account:** password user on the staging project (D30 rationale).

### 2.7 Push (APNs)

D35: real push for new request, acceptance, new message.

1. App asks permission in onboarding behind a single-"Continue" primer (D8, D31); denial never blocks.
2. On grant: `registerForRemoteNotifications` → `register_device_token(token, environment)` (`device_tokens`, `N-DM`).
3. Triggers on `requests` insert (recipient), `requests` → accepted (sender), `messages` insert (other participants, unless `muted`) insert a row into `notification_outbox(recipient_id, kind, route jsonb, created_at, sent_at, error)` in the same transaction.
4. A Supabase Database Webhook on `notification_outbox` INSERT calls `send-push`, which sends APNs with `route` in the payload and prunes invalid tokens (`N-BF` send-push).
5. Tap → `AppRoute` (request → Suki tab; message → Home › Inbox › conversation) (`R-IOS §1.5`).

Payloads carry no message body (lock-screen privacy) [design]: "New message from @handle". Outbox gives retries and a pgTAP-testable seam without APNs. Needs: APNs auth key (`.p8`), Team ID, Key ID in Edge Function secrets; Push capability on the App ID (HITL; needs the Apple Developer account, deferred by D39). Simulator remote-push on Apple silicon **[unverified here]**; test on device. Until D39 lifts, the outbox and `send-push` are verified with pgTAP and a mocked APNs endpoint only.

### 2.8 Matching: SQL `recommend`, weights table, reason codes

**Plain language.** For every candidate project or person, the database asks two questions: "does this fit what I want?" and "would they want me?". It combines both so a one-sided fit ranks low. It hides anything blocked, incompatible on pay or location, expired or already requested. It returns at most a small set, each with 2–4 reasons like "Needs your role" and "Both in Berlin". No scores or percentages are shown.

**Decision.** D15 (simple, transparent, rule-based, in Postgres, replaceable) wins over Notion's "Stage 2–3 in a TypeScript Edge Function with pgvector" (`N-ALG`, `N-BF` recommendations). Within D15, I adopt Notion's v1 formula because it is already the product owner's spec (`N-ALG` Part 2), and drop what v0 data cannot support. OD-1 records the alternative (research's additive points, `R-BE §2.4`).

**Contract (stable, replaceable)** (`R-BE §2.2`, extended):

```
recommend(surface text /* 'home_projects' | 'home_people' | 'onboarding_preview' */,
          p_limit int default 10)
returns table(target_type text, target_id uuid, band text, rank int,
              reasons jsonb /* [{code, params}] */, rules_version text)
```

- `security definer` (it must read other users' private `profile_settings` for logistics, per `N-DM`), owned by a dedicated role, re-applies `private.is_blocked` explicitly, and returns only IDs, band, rank and reason codes. Client then loads cards through normal RLS-checked selects (`R-BE §2.2`).
- Dispatches to `private.recommend_v1(...)` via `app_config.recommender`; v2 swaps behind the same signature.
- Logs each call to `recommendation_sets` / `recommendation_items` (service-role only; `N-DM`), including component values and `rules_version` (`N-ALG` Part 3).

**Stage 0 — eligibility (hard filters)** (`N-RS` Stage 0; `N-ONB` matching rules; D3):
- Not self; no block either way; viewer has not reported the candidate.
- Person: onboarding complete, handle, realm, primary role, `discoverable = true`, account `active`, not `hidden_at`.
- Project: `published`, `expires_at > now()`, not `hidden_at`, ≥1 `open` role; owner passes the person rules.
- No pending/accepted request between viewer and target; not hidden / not-my-style by viewer.
- **Compensation:** viewer preference `paid` → project `compensation_status in (paid, either)`; otherwise no filter (D3; `N-ONB` table). For people, see OD-12.
- **Work mode:** remote ↔ remote/either; local ↔ same `city_id` with local/either; either ↔ both (`N-ONB`). If fewer than 3 local results, add remote-compatible ones with reason `remote_fallback` (`N-ONB` C4).
- Availability is never a hard filter (`N-RS`).

**Stage 2 — components** (each 0..1; `N-ALG` Part 2 weights, stored in `ranking_weights(rules_version, key, value)` so tuning is data, D15):

| Component | Weight | v0 computation |
|---|---|---|
| Role R | 0.30 | 1.0 candidate primary role fills an open role the viewer needs (or viewer's primary role fills candidate project's open role); 0.8 secondary role; 0.4 same realm, other role. Person↔person: 1.0 complementary, 0.5 same role (`N-ALG`). Role adjacency table deferred (no taxonomy owner yet). |
| Taste T | 0.25 | 0.6 × facet similarity (confidence-weighted cosine over `taste_facets` rows, plain SQL, no pgvector) + 0.4 × favourites overlap (rarity-weighted, `N-ALG` Part 1b; 0.5 if either side has none). Cold start: if viewer's mean confidence < 0.3, weight 0.10 and the 0.15 goes to R and L (`N-ALG`). |
| Logistics L | 0.20 | Mean of work mode (1.0 match, +0.1 same city, cap 1), availability (same 1.0, neighbour 0.7, varies 0.8, two apart 0.4), timeframe (overlap 1.0, unknown 0.7) (`N-ALG`). |
| Intent I | 0.15 | Start→Join 1.0, Start→Start 0.6, any Explore 0.5; +0.2 if project type in preferred types, cap 1 (`N-ALG`). |
| Trust & freshness F | 0.10 | Mean of verified email (1.0 / 0.6) and freshness: `exp(-days_since_active/30)` people, `exp(-project_age_days/21)` projects (`N-ALG`). |

`D(a→b) = Σ weight × component`; `score = 2·D(a→b)·D(b→a) / (D(a→b)+D(b→a))`; hide below **0.35** (`N-ALG`, `N-RS`). Complementarity bonus +0.05 kept (`N-ALG`).

**Stage 3 — v0 simplification.** Bands from raw taste cosine (close ≥ 0.6, adjacent 0.3–0.6, stretch < 0.3 only if R ≥ 0.8, L ≥ 0.6 and a common thread exists) (`N-ALG`). Fill by serendipity mix (Stay close 80/15/5, Mix it up 60/30/10, Surprise me 40/40/20; `N-RS`). Max 2 items per owner (`N-RS`). New-creator exposure floor 1 in 10 (`N-ALG`). **Dropped for v0:** MMR diversity, ±0.03 jitter (keeps output deterministic for tests and seed review), weekly re-fit, weak ties, 10-minute set cache. Tie-break `(score desc, published_at desc, id)` (`R-BE §2.4`).

**Reasons.** Codes + params, never English, never numbers (`R-BE §2.2`; `N-ALG` "Never show scores, percentages or the underlying facet strengths"). 2–4 highest-contributing true reasons. v0 codes, mapped from `N-ALG` "Reasons":

| Code | Shown as (copy is a design-round task) | Condition |
|---|---|---|
| `needs_your_role` | Needs your role | R = 1.0 |
| `similar_taste` (`{family}`) | Similar sense of {family} | shared facet, both strength×confidence > 0.3 |
| `shared_favourite` (`{title}`) | You both listed {title} | shared favourite; both favourites public |
| `same_project_type` | Open to the same kind of project | type in preferred types |
| `same_window` | Available in the same window | same availability band |
| `same_city` (`{city}`) | Both in {city} | same city, local/either |
| `works_remotely` | Works remotely | both remote-compatible |
| `remote_fallback` | No local matches yet, so here is a remote one | Stage 0 fallback |
| `stretch_pick` | A stretch pick based on your discovery setting | band = stretch; always with one common-thread reason |
| `new_creator` | New on Kizuki | exposure-floor slot |

**Performance.** v0 seed (60 users, 25 projects; `R-BE §6.2`) makes this trivially fast; `N-ALG` budget (< 400 ms p95 whole call) is the target to measure with `EXPLAIN` once a stack runs **[unverified until measured]**.

### 2.9 Safety: report, block, auto-hide

- **Report** on every UGC surface: other profile, project, collab photo, request, message, embed (Apple 1.2; `R-IOS §4.2`). `submit_report` stores category, optional context and a `snapshot` jsonb of the reported content (survives sender deletion) (`R-BE §1.7`). Reporter's view hides the item immediately; confirmation offers "Also block" (`R-IOS §4.2`). Categories: spam, harassment_or_hate, sexual_content, violence_or_threats, scam_or_impersonation, underage, intellectual_property, other [design, union of `R-BE §1.2` and `R-IOS §4.2`].
- **Review:** user reviews daily in the Supabase dashboard, 24-hour target (D16, D34). Status `open → reviewing → actioned | dismissed`; actions = set `hidden_at`, set profile `status = suspended`, or delete content. No reviewer UI, no appeals (D16).
- **Auto-hide (D34):** trigger on `reports` insert: when **3 distinct reporters** (OD-6) have open reports on the same subject, set `hidden_at = now()` on it (profile → suspended-pending-review flag). Hidden content fails Stage 0 and every read policy except the owner's. Never auto-ban (`N-TS`).
- **Block:** `block_user` inserts the row and, in the same transaction, withdraws pending requests both ways (`N-BF`), closes the pair's direct conversation (`closed_at`, reason `blocked`), and removes the pair's likes/saves. Restrictive policies hide profiles, projects, collab photos, favourites, links, requests and storage reads both ways (`R-BE §1.10`). The blocked user never learns they were blocked: `blocks` is readable only by the blocker (`R-BE §1.9`). Blocked list with Unblock in Settings (`R-IOS §4.2`).
- **Text filter (Apple 1.2 "filtering"):** a `before insert/update` trigger on handles, display names, bios, project text, captions, request and chat messages checks a `blocked_terms` table (profanity/slur list) and rejects with `validation_failed`. Images: no automated filter in v0 (D34 rules out a paid moderation API); mitigation is report + auto-hide + daily review. This is a Beta App Review risk (Risk 3).
- **Rate limits** (server-side, `N-BF`): requests 5/day for accounts < 7 days, 20/day otherwise; reports 10/day; handle checks 30/min; chat sends 30/min [design].
- **Contact:** support email and URL in Settings › Help and in App Store Connect (Apple 1.2, 1.5; `R-IOS §4.2`).

### 2.10 Embeds (profile widgets)

D23 + AD: YouTube, SoundCloud, Bandcamp = embedded players; Instagram, Letterboxd, website, others = link-out chips.

- Stored in `portfolio_sources` (`N-DM`) with `source_type`, `canonical_url`, `embed_ref` (provider ID parsed from URL; nullable), `source_relation` (made/admire/want_to_make; Letterboxd defaults admire), `public_display_consent` (default false), `recommendation_use_consent` (default false; unused by v0 ranker) (`N-ONB` C3).
- Host allow-list enforced twice: client parser (`KizukiEmbeds`, pure, unit-tested) and a DB trigger; `https://` only (`R-IOS §5.1`, `§5.8`).
- Rendering: native facade card first, no third-party request until tap; then `WKWebView` with non-persistent data store, inline playback, user-action-required media, navigation locked to the provider's player host, outbound links to `SFSafariViewController` (`R-IOS §5.1`).
- YouTube: Referer `https://club.kizuki.ios` (bundle ID as HTTPS origin), ≥200×200 viewport, no overlays; error 101/150/153 → "Open in YouTube" (`R-IOS §5.3`). Terms and privacy policy must reference YouTube ToS and Google Privacy Policy.
- SoundCloud widget with `download=false&buying=false&auto_play=false`; attribution backlink (`R-IOS §5.4`).
- Bandcamp: accept only Bandcamp's own embed code; extract `src` matching `^https://bandcamp\.com/EmbeddedPlayer/` **[unverified path shape]**; otherwise link card (`R-IOS §5.5`).
- Every embed has "Report" and disappears when the owner is blocked.
- No server-side link validation or weekly recheck in v0 (`link_status` null = unchecked).

### 2.11 Taste cards and favourites

- **Taste cards (D21):** onboarding O4 shows 12 cards, pick 3–5; O5–O7 three pairwise choices (left/right/neither/both), up to 2 follow-ups only when low-confidence (`N-ONB` O4–O7). Cards are placeholder art generated by script with `license_ref = 'placeholder'` (`R-BE §6.3`); ≥24 per realm (`N-ONB`). A release-checklist pgTAP test fails if any active card is a placeholder in a release dataset (`R-BE §1.4`). Facet taxonomy (60–120 values in families, `N-ALG` Part 1) is ticket 007; v0 seeds a small provisional set (≈30 values, 6 families) [design] so the pipeline runs end to end.
- **Facet maths:** `submit_taste` applies `N-ALG` update rules (selected +1.0, shown-not-selected −0.1, pairwise chosen +1.0 / other −0.3, neither −0.3, both +0.5) into `taste_facets(signal_sum, evidence_count)`; strength `clip(S/(N+2), −1, 1)`, confidence `N/(N+3)` (`N-ALG`). Feedback events (save +0.3, not my style −0.6, hide −0.2, accepted request +0.8) applied by `record_feedback` / `respond_request`. Decay deferred.
- **Favourites (D22):** in-app picker; films via `tmdb-proxy` (TMDB), music (artists, release groups) direct from device to MusicBrainz with a 1.1 s serial queue, 600 ms debounce, `User-Agent: Kizuki/<ver> (<contact>)` (`R-IOS §6.2`; `R-BE §1.8`). Stored per profile in `favourites(profile_id, source, kind, external_id, title, year, position, refreshed_at)`, max 5 per kind, as in `R-BE §1.4`. Rarity weighting for overlap is computed by counting profiles per `(source, external_id)`. Notion's shared `references` catalogue (`N-DM`) is deferred: with client-supplied titles, a shared catalogue lets one user write text everyone sees, and `references` is a reserved word in SQL (Appendix A). No posters or cover art stored; TMDB posters hotlinked; music tiles text-only (AD). TMDB data refreshed within 6 months (TMDB terms, `R-BE §1.8`). TMDB attribution in Settings › About (`R-IOS §6.1`).
- Favourites shown on profile only when the owner's `public_display_consent` for favourites is on [design]; they feed matching (`shared_favourite`, rarity-weighted overlap).

---

## 3. Environments and config guardrails

### Plain language

Four places the app can run, each with its own database. Your laptop (fake data, safe to wipe), the CI robot (wipes itself every run), a cloud **staging** project for TestFlight (fake data only), and **production** (real, empty, not touched in v0). The app is built so a build for one place physically cannot talk to another.

### Detail

| Env | Backend | App build | Data | Status |
|---|---|---|---|---|
| **Local** | `supabase start` at `http://127.0.0.1:54321` (CLI pinned `supabase@2.122.0`) | Debug, scheme `Kizuki-Local`, bundle `club.kizuki.ios.local` | `supabase/seed.sql` (generated) + `scripts/seed-storage.py` uploads; Inbucket/Mailpit for email | **Blocked:** no container runtime (ticket 005). Native runtime works for Postgres/pgTAP but uses random ports (`R-BE §7.3`) |
| **CI** | GitHub Actions `local-backend` job: `supabase start/reset/test` on `ubuntu-latest` (Docker) | `ios` job: Local scheme on `macos-15`, Xcode 26.0.1, iPhone 16e simulator | Same seed | Exists (`.github/workflows/foundation.yml`) |
| **Staging** | `https://ankgfqkgflcalmlreetu.supabase.co` (ref `ankgfqkgflcalmlreetu`) (D29, D38) | Staging config, archived to TestFlight. Simulator/device builds against staging work now; **TestFlight distribution is blocked on Apple Developer enrolment, which the user has deferred (D39)** | Seed only, fictional `@seed.kizuki.test` users (`R-BE §6.4`) | Exists. Still needed: publishable key in `Staging.private.xcconfig` (not yet supplied, D38), `SUPABASE_URL` in `Staging.xcconfig`, custom SMTP, Apple provider + APNs key (both need the Apple account, D39), TMDB key in function secrets |
| **Production** | `enosggckdxjiaqtxalhg` | Release config | None | **Untouched in v0** (D10, D29). First migration push is a separate human-gated release step |

**Local runtime caveat.** Two paths (`R-BE §7.2–7.4`):
- OrbStack/Colima (ticket 005): conventional, matches CI, keeps port 54321 so `AppConfiguration` (requires `http`, `127.0.0.1|localhost`, port **54321** for `.local`; repo `AppConfiguration.swift`) and `scripts/local_backend.py::require_local_url` keep working. **Recommended** (OD-9).
- Native runtime (`supabase start --runtime native`, experimental): ran the existing migration and passed all 10 pgTAP tests, but used random ports (gateway 26333 in that run); `supabase-local.sh` checks `docker info` first; `status --output json` unsupported (`R-BE §7.3`). Usable for SQL/pgTAP work today. Using it for the app needs a patch: allow a configured local port in `AppConfiguration` and the guard script (slice A2 contingency). Realtime, Storage and Edge Functions were not exercised on it.
- Not blocked without a stack: all SwiftUI work on fixtures, writing migrations/tests as text, seed generation, CI runs (`R-BE §7.4`).

**Guardrails (keep and extend).**
1. `AppConfiguration` rejects service-role/secret keys, rejects a Staging URL equal to the production host, and pins Production to `enosggckdxjiaqtxalhg.supabase.co` (repo `AppConfiguration.swift`). Keep.
2. `validate-release-config.sh` pre-build script blocks bad Release/Staging config (repo `project.yml`). Keep.
3. Keychain session key per environment + URL (`sessionStorageKey`), so a staging session never leaks into a production build. Keep.
4. Seeds never ship: only migrations go to remote projects; never `db push --include-seed`; `seed.sql` aborts unless every `auth.users` email ends `@seed.kizuki.test`; taxonomy rows (roles, project types, cities, facets, blocked terms, buckets) live in migrations, people/projects in seed; CI greps migrations for inserts into user tables (`R-BE §6.4`).
5. `scripts/supabase-local.sh` contains no `link`, `db push` or `--db-url` (`R-BE §6.4`). Staging pushes go through a separate script that requires `--project-ref` equal to the staging ref and refuses the production ref [design].
6. Edge Function secrets (service role, APNs key, TMDB key) live only in Supabase function secrets; the app holds the publishable key only (`N-ARCH` Auth).
7. `KizukiTestSupport` is never linked into Release; fixture backend only behind `#if DEBUG` launch arguments.

**Repo facts the plan must fix.**
- `Staging.xcconfig` sets `KIZUKI_BUNDLE_ID = club.kizuki.ios.staging` and an empty `SUPABASE_URL` (repo). `R-IOS §1.1` says Staging uses `club.kizuki.ios`; the repo disagrees. A separate bundle ID needs its own App ID, capabilities and App Store Connect record. OD-5 recommends one record (`club.kizuki.ios`) for TestFlight.
- `config.toml`: `[storage] enabled = false`, `[edge_runtime] enabled = false`, `[db.seed] enabled = false`, `[studio] enabled = false` (repo). Slices enable each when first needed.
- Existing `handle_format` allows 3–24 chars; AD says 3–20. Migration in slice A2 tightens it (no real data exists).

---

## 4. Data model

### 4.0 Plain language

About 30 tables in five groups: **who you are** (profile, private settings, roles, taste, favourites, links), **what you make** (projects, roles needed, members, collab photos), **how you connect** (requests, conversations, messages), **staying safe** (blocks, reports), and **how matching learns** (feedback, weights, logs). Anything private (pay preference, availability, city, onboarding answers, taste scores) sits in tables only you can read. Requests and projects move through fixed states, and only the database moves them.

Reconciliation against Notion `N-DM`: Notion names and enums are used unless a locked decision, agent default or a concrete defect says otherwise. Every difference is in Appendix A.

### 4.1 Enums

| Enum | Values | Source |
|---|---|---|
| `realm` | film_video, music_sound, visual_arts, mixed_practice | `N-DM` |
| `intent` | start, join, explore | `N-DM` |
| `serendipity` | stay_close, mix_it_up, surprise_me | `N-DM` |
| `availability_band` | under_5, five_to_10, over_10, varies | `N-DM` |
| `work_mode` | local, remote, either | `N-DM` |
| `compensation_preference` | paid, unpaid, either | `N-DM` |
| `compensation_status` | paid, unpaid, either, undecided | `N-DM`; `undecided` only on drafts (CHECK) |
| `pairwise_choice` | left, right, neither, both | `N-DM` |
| `source_relation` | made, admire, want_to_make | `N-DM` |
| `link_status` | ok, unreachable, hidden (column nullable = unchecked) | `N-DM` |
| `project_status` | draft, published, closed, past | AD (Notion has 6; Appendix A) |
| `project_closed_reason` | filled, owner_closed, expired, completed | AD + `R-BE §1.2` |
| `request_kind` | join_project, collab_person, invite_to_project | D36; `R-BE §1.5` |
| `request_status` | pending, accepted, declined, withdrawn, expired | `N-DM` |
| `feedback_kind` | like, save, more_like_this, less_like_this, not_my_style, hide | `N-DM` + `like` (D25) |
| `account_status` | active, suspended | [design]; deactivate deferred |
| `report_status` | open, reviewing, actioned, dismissed | `R-BE §1.2` |

### 4.2 Tables, columns, relationships, RLS

`me` = `(select auth.uid())`. "Visible" = passes the restrictive `private.is_blocked` policy and the target is not `hidden_at` (except to its owner). "RPC" = no table grant; writes only through a `security definer` function.

**Identity and profile**

| Table | Key columns | Relationships | RLS (select / write) |
|---|---|---|---|
| `profiles` (exists; extend) | id, handle citext (3–20, AD), display_handle, display_name, bio (≤280), avatar_path, primary_realm, secondary_realms realm[], onboarding_completed_at, discoverable bool default true, status account_status, hidden_at, last_active_on date | id → `auth.users` cascade | Own row always; others if onboarding complete, discoverable, active, not hidden, visible (`N-DM`). Update own via column grants (display_name, bio, avatar_path, secondary_realms); handle via `set_handle`; status/hidden by service role only |
| `profile_settings` (exists; extend) | profile_id, primary_intent, serendipity default mix_it_up, availability_band, work_mode, city_id, country_code, city_unlisted, compensation_preference, preferred_project_type_ids uuid[], discovery_focus text[], onboarding_state jsonb, show_favourites bool default false, notify_requests, notify_messages | 1:1 profiles | Owner only (`N-DM`). Read by `recommend` (definer) |
| `legal_acceptances` | id, profile_id, terms_version, privacy_version, age_confirmed, accepted_at (server) | → profiles cascade | Owner select; insert via `accept_terms` only; no update/delete (`N-DM`) |
| `roles` | id, slug, label, realm (null = cross), is_common, sort | — | All authenticated read; migrations write |
| `project_types` | id, slug, label, realm | — | Same |
| `cities` | id, name, country_code, coarse_lat, coarse_lng | — | Same. Small curated list, Berlin first (`R-BE §1.3`) |
| `profile_roles` | profile_id, role_id, is_primary, position | → profiles, roles. PK (profile_id, role_id); partial unique (profile_id) where is_primary; 1–3 rows (trigger) | Owner + visible profiles / owner write |
| `favourites` | id, profile_id, source (tmdb, musicbrainz), kind (film, artist, release_group), external_id, title, year, position, refreshed_at | → profiles. Unique (profile_id, source, external_id); ≤5 per kind | Owner; others if owner `show_favourites` and visible / owner write |
| `portfolio_sources` | id, profile_id, source_type, canonical_url, embed_ref, display_title, source_relation, public_display_consent default false, recommendation_use_consent default false, consent_updated_at, link_status, position | → profiles. CHECK https; host allow-list trigger | Owner; others if `public_display_consent` and visible (`N-DM`) / owner write |
| `device_tokens` | profile_id, token, environment (sandbox, production), updated_at | → profiles. PK (profile_id, token) | Owner (`N-DM`) |

**Taste**

| Table | Key columns | Relationships | RLS |
|---|---|---|---|
| `facet_catalog` | id, family, value, is_shared_family, medium realm null | — | All authenticated read (taxonomy; ticket 007) |
| `taste_items` | id, realm, media_path, alt_text, descriptors text[], license_ref, active | — | All authenticated read (`N-DM`) |
| `taste_item_facets` | item_id, facet_id, weight (0..1) | → taste_items, facet_catalog | All read. Needed because `N-ALG` weights facets per card; `N-DM` stores only `facet_ids text[]` |
| `taste_pairs` | id, realm, left_item_id, right_item_id, target_facet_ids uuid[], active | → taste_items | All read (`N-DM`) |
| `taste_seed_selections` | profile_id, item_id, selection_order | → profiles, taste_items | Owner / RPC `submit_taste` |
| `pairwise_answers` | profile_id, pair_id, choice, response_ms null, is_followup | → profiles, taste_pairs | Owner / RPC. `response_ms` stored for research only, never read by ranking (`N-DM`, `N-ONB` O5–O7) |
| `taste_facets` | profile_id, facet_id, medium, signal_sum, evidence_count, explicit bool, updated_at | → profiles, facet_catalog | Owner / RPC only. Strength and confidence derived (`N-ALG` Part 1) |

**Projects and content**

| Table | Key columns | Relationships | RLS |
|---|---|---|---|
| `projects` | id, owner_id, status, closed_reason, realm, project_type_id, project_type_other (≤40), title, description, compensation_status, work_mode, city_id, country_code, time_commitment availability_band, starts_on, ends_on, expires_at, published_at, cover_path, hidden_at | → profiles (owner, cascade), project_types, cities | Owner always; others if status in (published, closed, past) and visible; members always / insert owner as draft; update owner on content columns; status only via RPC; delete owner drafts only |
| `project_roles` | id, project_id, role_id, status (open, filled), note | → projects cascade, roles. One row per seat | Follows parent / owner write while draft or published; status via RPC |
| `project_members` | project_id, profile_id, project_role_id, joined_at | → projects, profiles, project_roles | Where project visible / RPC only (`respond_request`) |
| `collab_photos` | id, owner_id, storage_path_prefix, width, height, caption (≤140), alt_text, realm, role_id, tags text[], project_id null, hidden_at, created_at | → profiles cascade; ≤24 per owner (trigger) | All authenticated where not hidden and visible; owner always / owner insert (prefix starts with `me`) and delete |
| `recommendation_feedback` | profile_id, target_type (project, profile, collab_photo), target_id, kind, set_id null, created_at | → profiles. PK (profile_id, target_type, target_id, kind) | Owner only (`N-DM`). Likes are private signals; no public counts (OD-8) |

**Requests and chat**

| Table | Key columns | Relationships | RLS |
|---|---|---|---|
| `requests` | id, kind, sender_id, recipient_id, project_id, project_role_id, idea_text, message (≤500), status, conversation_id, expires_at (created + 14 d), created_at, resolved_at | sender/recipient → profiles **set null** (AD "Deleted user"); project → projects set null | Sender or recipient, visible / RPC only (`N-DM`) |
| `request_decline_reasons` | request_id, reason | → requests cascade | Recipient only. Split out so the sender can never read it (`N-ONB`/Product Requirements "Decline reason is optional and private") |
| `conversations` | id, kind ('direct'), pair_low, pair_high, origin_project_id, created_at, closed_at, closed_reason (blocked) | Unique (pair_low, pair_high) | Participants / RPC only (`N-DM` "Created only by the respond-request function") |
| `conversation_participants` | conversation_id, profile_id, joined_at, last_read_at, muted | PK (conversation_id, profile_id) | Participants / update own `last_read_at`, `muted` |
| `messages` | id, conversation_id, sender_id (set null), client_id, body (1–2000), created_at | Unique (sender_id, client_id); index (conversation_id, created_at desc) | Participants / insert: sender = me, participant, conversation open, not blocked; no update/delete (OD-10) |
| `notification_outbox` | id, recipient_id, kind, route jsonb, created_at, sent_at, error | → profiles cascade | Service role only |

**Safety and matching**

| Table | Key columns | RLS |
|---|---|---|
| `blocks` | blocker_id, blocked_id, created_at; PK pair; CHECK distinct; index (blocked_id, blocker_id) | Blocker only / RPC `block_user`, `unblock_user` |
| `reports` | id, reporter_id (set null), subject_type, subject_id, subject_owner_id, category, context (≤1000), snapshot jsonb, urgency, status, created_at, reviewed_at, reviewer_note | Reporter's own rows / RPC `submit_report` (`N-DM`) |
| `private.blocked_terms` | term, kind | Not exposed (private schema) |
| `private.ranking_weights` | rules_version, key, value | Not exposed |
| `private.app_config` | key, value (e.g. `recommender = v1`) | Not exposed |
| `recommendation_sets`, `recommendation_items` | per `N-DM` | Service role only (`N-DM`) |

**Deferred from `N-DM` (not in v0):** `taste_vectors` (pgvector), `references`/`profile_references` catalogue, `release_credits`, `consent_events`, `project_references`, `collaborations`, `collaboration_participants`, `made_together_posts`, `moderation_actions`, `appeals`, `analytics_events`, `reserved_handles` holding period (reserved list kept as `private.blocked_terms` kind `reserved`).

**Indexes** on every column used in a policy or join: owner_id, sender_id, recipient_id, conversation_id, profile_id, project_id; `projects (status, expires_at) where status = 'published'`; `project_roles (project_id) where status = 'open'`; `blocks (blocked_id, blocker_id)`; GIN on `collab_photos.tags`; trigram on caption **[unverified extension availability]** (`R-BE §1.9`, §1.7).

### 4.3 Request state machine

```
            send_request (sender)
   (none) ───────────────────────► PENDING
                                     │
     respond_request(accept) ────────┼──► ACCEPTED   [terminal]
       by recipient                  │      side effects: reuse/create direct conversation,
                                     │      add participants, link requests.conversation_id;
                                     │      join/invite: insert project_members, role → filled,
                                     │      last open role filled → project CLOSED(filled),
                                     │      other pending requests for that role → EXPIRED;
                                     │      outbox push to sender; taste +0.8 both
     respond_request(decline) ───────┼──► DECLINED   [terminal] optional private reason
       by recipient                  │
     withdraw_request (sender) ──────┼──► WITHDRAWN  [terminal]
     block_user (either party) ──────┤      (system withdraw)
                                     │
     cron daily / lazy read ─────────┴──► EXPIRED    [terminal]
       expires_at < now(); or project leaves PUBLISHED; or role filled
```

- Who is "recipient": `join_project` → project owner; `invite_to_project` → invited person (sender must own the project); `collab_person` → the person (project optional; `idea_text` required when no project) (D36; `N-DM`).
- Gate on send: completed onboarding, verified email, primary role, not blocked either way, recipient active and not hidden, project `published` and role `open`, compensation filter for join (D3), rate limit 5/20 per day (`N-BF`). Errors use `N-BF` codes.
- Duplicate guard: partial unique index on `(sender_id, recipient_id, coalesce(project_id, zero_uuid))` where status in (`pending`, `declined`) — a declined person cannot be re-asked for the same project [design; `N-DM` covers pending only].
- Terminal states are final (BEFORE UPDATE trigger rejects changes); clients have no UPDATE grant (`R-BE §1.5`).

### 4.4 Project status machine

```
  DRAFT ──publish_project──► PUBLISHED ──last role filled──► CLOSED(filled)
    │  (validates contract)    │   ▲                              │
    │                          │   └──reopen_project─────────────┤ (owner adds open role, not expired)
  delete (owner)               ├──close_project──► CLOSED(owner_closed) ──reopen──► PUBLISHED
                               │
                               ├──expires_at passes──► PAST(expired) ──renew (new expires_at)──► PUBLISHED
                               └──mark done──► PAST(completed)      CLOSED ──mark done──► PAST(completed)

  hidden_at (moderation) is orthogonal: hides any status from everyone but the owner.
```

- Publish contract (CHECK + RPC; `N-DM`, `N-ONB` data contract, Product Requirements "Project fields"): title, description, realm, project type (other text if Other), compensation ≠ undecided, work mode, city if local/either, `expires_at` (default publish + 30 days, OD-13), ≥1 open role (trigger), owner email verified. Other-type text passes the `blocked_terms` filter (`N-BF` publish-project "moderates the Other type text").
- Leaving PUBLISHED expires that project's pending requests.
- Notion's eight product statuses map as: Draft → draft; Open/Partially filled → published; Filled → closed(filled); Closed → closed(owner_closed); Expired → past(expired); Completed → past(completed); In progress → published or closed (no separate state in v0); Hidden → `hidden_at` (AD; Appendix A).

### 4.5 Account deletion data rules

Per AD ("messages/requests remain as 'Deleted user'") and `R-BE §4.4`:

| Data | On delete |
|---|---|
| auth user, profile, settings, roles, taste, favourites, links, device tokens, feedback, blocks (both directions), legal acceptances | Cascade |
| Storage objects (avatar, collab photos, project covers) | Removed by `delete-account` via Storage API **before** `deleteUser` (users owning objects cannot be deleted; `R-BE §4.4`) |
| Owned projects (any status), their roles and members | Cascade (OD-7) |
| Messages sent | Kept; `sender_id` → null; shown as "Deleted user" |
| Requests sent/received | Kept; party id → null |
| Conversations | Kept for the other participant; deleted user's participant row cascades |
| Reports filed by the user | Kept; `reporter_id` → null |
| Reports about the user | Kept with `snapshot` for review; retention period pending legal (AD) |
| Recommendation logs | Cascade via profile_id [design] |
| Apple token | Not revoked in v0; Apple TN3194 fallback: tell the user to revoke in Apple ID settings, handle `credentialRevokedNotification` (`R-BE §4.4`). Full revocation is a launch hardening item |

---

## 5. Main flows, step by step

Each flow: what the person does → what the app calls → what the database enforces. Screen names refer to section 9.

### 5.1 Onboarding (first launch to Home)

1. **Entry** (splash → Create account / Log in). Choose Apple or email (D13; FIG §1 drops Google).
2. **Apple:** system sheet → `signInWithIdToken(.apple, nonce)` → `auth.users` insert → existing `provision_profile` trigger creates `profiles` + `profile_settings` with id only (repo migration). **Email:** email + password (10+) → `signUp` → **Verify email** screen, 6-digit code → `verifyOTP(.signup)` (OD-3).
3. **Handle + name** (Auth 2): debounced `handle_available` → `set_handle`. Display name optional; Apple first-sign-in name pre-filled if the user confirms (`R-BE §4.1`).
4. **Terms + 18+** (Auth 3): unticked checkbox "I am 18 or older and agree to the Terms", Terms/Privacy links → `accept_terms`. Unticked = cannot continue. Self-declared under-18 → explanation → client calls `delete-account` and signs out; nothing else stored (`N-TS` Minors; `R-BE §4.3`).
5. **Realm** (O2) → **Intent** (O3) → **Taste cards** (O4: 12 cards, pick 3–5) → **Pairwise** (O5–O7: 3 + up to 2) → **Serendipity** (O8, default Mix it up) → **Roles** (O9: 1–3, first is primary). Each step `save_onboarding_step` (`N-BF`); answers resumable.
6. **Branch:** Start → S1 project type, S2 roles needed, S3 compensation. Join → J1 project interests, J2 compensation preference. Explore → E1 discovery focus (`N-ONB`).
7. **Availability** (C1; Start/Join) → **Location primer** (single "Continue" → system prompt; granted → one-shot reduced-accuracy fix → on-device reverse geocode → suggested city; denied → manual city search, pre-filled Berlin; coordinates never stored) (D8, D31, AD; `R-IOS §2.3`) → **Work mode + city** (C2).
8. **Notifications primer** (single "Continue" → system prompt; denial never blocks) (D8, D31, D35) → on grant `register_device_token`.
9. **Favourites** (optional): films via `tmdb-proxy`, music via MusicBrainz; skip allowed (D22).
10. **Your work** (C3, optional): links with "This is" relation and two consents off by default (`N-ONB` C3).
11. **Profile photo** (optional; Blobatar fallback, D9) (FIG §1 `1312:12172`).
12. **Preview** (C4): `submit_taste` (if not already) → `complete_onboarding()` → `recommend('onboarding_preview', 5)`; 3–5 cards with reasons, or the empty-state copy if fewer than 3 pass (`N-ONB` C4). "Enter Kizuki" → Home. Start users see a "Finish your project" card on Home (D7).

Skip from O4 onward enters Home with completed answers only; the missing-fields sheet appears before sending a request or publishing (`N-ONB` Skip behavior).

### 5.2 Home feed

1. Home tab appears → `recommend('home_projects', 10)` and `recommend('home_people', 8)` in parallel → client loads cards with RLS selects (`projects`, `project_roles`, `profiles`) for the returned IDs.
2. Sections: "Finish your project" card (if the user owns an unfinished Start draft, D7) → Recommended projects → People you might like (D19; FIG §3).
3. Each card shows reasons (2–4) and actions: like, save, overflow (Not my style, Hide, Report) → `record_feedback` / `submit_report`.
4. Tap project → **Project detail** (roles, timing, compensation label, collaborators, owner) → "Ask to join" → request composer (5.3). Tap person → **Profile (other)** → "Ask to collaborate" → composer.
5. Top bar: Inbox icon → Inbox; gear → Settings; avatar entry not in top bar (D19 supersedes D6; Profile is a tab).
6. Empty state if `recommend` returns fewer than 3 (copy from `N-ONB` C4).

### 5.3 Request / invite → accept → chat (the core loop)

1. **Compose.** From project detail ("Ask to join": `join_project`, pick an open role), other profile ("Ask to collaborate": `collab_person`, optional own project, else idea text), or My Projects › project › "Invite" (`invite_to_project`, pick role) (D36). Message ≤500 chars.
2. **Send.** `send_request(...)`. Server checks onboarding, verified email, primary role, block, duplicate, project/role state, compensation, rate limit. On `missing_fields` the app shows one sheet asking only for those fields (`N-BF`, `N-ONB` Skip behavior). Success → request `pending`; trigger writes `notification_outbox` → `send-push` → recipient gets "New request from @handle".
3. **Receive.** Recipient opens push or Suki › Requests › Incoming → **Request detail** (who, which project/role, message, reasons for fit) → Accept / Decline / Report / Block.
4. **Accept.** `respond_request(id, true)` → in one transaction: status `accepted`, reuse or create the pair's direct conversation, participants, `project_members` + role filled (join/invite), outbox push to sender "@handle accepted your request" (`N-BF` respond-request).
5. **Chat.** Both see the conversation in Inbox (Home top bar) and in Suki › Matches. Chat screen subscribes to Postgres Changes for that conversation; sends are inserts with `client_id`; other participant gets push "New message from @handle" (payload without body). Header shows project context, Report and Block.
6. **Decline** → `declined` (+ optional private reason). Sender sees "Not this time" with no reason [design]. **Withdraw** by sender while pending. **Expire** after 14 days.

### 5.4 Create project (Suki › Create, or "Finish your project" card)

1. Suki › Create → chooser: **New project** or **Post a collab** (FIG §5 `1361:12435`; labels **[unverified]**).
2. New project form (one scrolling form in v0; stepper is a design-round choice): title, description, realm, type (or Other ≤40), roles needed (1+ seats), compensation (Paid / Unpaid collaboration / Open to either; `undecided` allowed only in draft), work mode, city, time commitment, start/end or flexible, optional cover photo (`project-covers`). Saves as `draft` on first edit (server-side drafts, `R-IOS §1.7`).
3. Publish → `publish_project(id)` validates the contract (4.4); on error the form highlights fields. Success → `published`, appears in others' recommendations; owner lands on Project detail with "Invite people".
4. Post a collab: pick photo (system picker; limited library access) → caption (≤140), realm/role/tags → client makes thumb + full renditions, strips EXIF → upload to `collab-photos/<uid>/<id>/` → insert `collab_photos` row (AD: separate content type).

### 5.5 My Projects

Segments [design, D19]: **Drafts** (owned drafts), **Published** (owned published + closed, plus joined projects that are published/closed, labelled "Joined"), **Past** (owned or joined, status past). Row → Project detail (owner view: Edit, Publish, Close, Mark done, Renew, Invite; member view: Open chat with owner). One RLS query per segment; no Realtime.

### 5.6 Search

1. Search tab → grid of recent visible `collab_photos` (3 columns, newest first, page of 30; signed thumb URLs in one batch call `createSignedURLs`) (`R-BE §5.3`).
2. Filter chips = tag values and realms (seeded 12 tags; FIG §4 chips "For you · motion design · creators · painting"). "For you" chip = photos from owners in the viewer's recommended people set [design].
3. Search bar: caption + tag + handle match (`ilike`/trigram) [design]; results show photos and a "People" row of matching handles (FIG `1312:9406`).
4. Tap tile → **Post viewer** (full image, caption, author, time; actions: like, save, Report, open author profile).
5. Empty and no-results states (FIG gap 13).

### 5.7 Profile view and edit + embeds

1. Profile tab = own profile: avatar (photo or Blobatar), display name, @handle, primary role + realm, bio, roles, favourites (if shown), links/embeds, collab photos grid, projects. "Edit profile" button.
2. Edit: name, bio, avatar (crop, upload to `avatars/<uid>/<uuid>.jpg`, update `avatar_path`), secondary realms, roles (1–3), favourites, links. Links: paste URL → client parser → provider + `embed_ref` → choose relation, "Show on my profile" → insert `portfolio_sources` (DB trigger re-checks host allow-list).
3. Other profile (from Home/Search/Suki): same layout, "Ask to collaborate" instead of Edit, overflow Report / Block. Embeds render as facade cards; tap → player sheet (2.10).
4. City display on profiles depends on OD-4.

### 5.8 Report and block

1. Any UGC overflow → Report → category list → optional context → `submit_report` → confirmation "Thanks. We review reports within 24 hours." with "Also block @handle" (`R-IOS §4.2`). Item disappears for the reporter immediately (client + Stage 0 exclusion).
2. Third distinct reporter → trigger sets `hidden_at` (OD-6). User reviews in Supabase dashboard daily (D34).
3. Block from profile, chat header or report confirmation → `block_user` → side effects (2.9) → blocked person vanishes everywhere for both; chat shows "This conversation is closed". Unblock in Settings › Privacy & Safety › Blocked accounts. Unblocking does not reopen closed conversations or restore withdrawn requests [design].

### 5.9 Delete account

1. Settings › Account › Delete account → explanation of what is removed and what remains ("Your messages stay visible to the people you sent them to, shown as Deleted user") (AD; `R-IOS §3.3`).
2. Re-authenticate: Apple → Sign in with Apple again; email → password.
3. Destructive confirm → `functions.invoke("delete-account")` with the user JWT.
4. Function: verify JWT → Storage API remove all objects under the user's prefixes in the three user buckets → `auth.admin.deleteUser(uid)` → cascades/set-null per 4.5 → 200.
5. App: `signOut(scope: .local)`, clear Keychain and caches → entry screen with "Your account was deleted". Apple users: show "Also remove Kizuki in Settings › Apple ID › Sign in with Apple" (TN3194 fallback, `R-BE §4.4`).
6. Failure mid-way is retryable (idempotent). UI test: delete returns to entry and signs out (`R-IOS §3.3`).

---

## 6. v0 vs later

**In v0**
- Apple + email/password sign-in, email verify by code, 18+ checkbox, handle 3–20 (D13, D30, AD).
- Onboarding v3.1 with permission primers up front, taste cards (placeholder art), pairwise choices, serendipity, roles, Start/Join/Explore branches, availability, work mode + city, favourites picker, links, preview (D8, D21, D22, D31).
- Five tabs: Home (feed: projects + people, Finish-your-project card), Search (collab photo grid, chips, search), Suki (matches, requests, create), My Projects (drafts, published, past), Profile (own); Inbox and Settings from Home top bar (D19, D32).
- Projects with four statuses + `closed_reason`, roles as seats, members, cover photo (AD).
- Collab photos (photo + caption) as a separate content type (AD).
- Requests both ways (join, collaborate, invite) → accept → direct chat; Postgres Changes; text only (D11, D36).
- Real APNs push for new request, acceptance, message (D35).
- SQL `recommend` with Notion v1 components, harmonic-mean reciprocity, threshold 0.35, bands, reason codes; logging (D15).
- Likes and saves (private), hide, not my style (D25).
- Report (all surfaces) + block (both ways, server-enforced) + auto-hide after 3 reporters + daily dashboard review + text blocklist (D16, D34).
- Embeds: YouTube, SoundCloud, Bandcamp players; Instagram, Letterboxd, others link-out (D23, AD).
- Delete account Edge Function; Apple revocation fallback copy.
- Local, CI, staging environments; seeded fictional data; TestFlight (D18, D29).

**Later (explicitly not v0)**
- Google sign-in (D13); payments (D12); follows and "Following" feed (D24); comments (D25); events; Made Together and completion (interview "Out of v0"); appeals and moderator tooling (D16); Suki AI assistant (AD).
- Group chats, attachments, message edit/unsend, typing/presence, Broadcast-based chat (OD-2, OD-10).
- pgvector taste vectors, Edge Function ranker, MMR diversity, jitter, weekly weight re-fit, weak ties, reference catalogue (`N-ALG`, deferred under D15).
- `validate-link`, weekly link recheck, oEmbed metadata, recommendation use of portfolio sources (`N-BF`).
- Instagram embed (v0.1 candidate, `R-IOS §5.6`); Letterboxd/Spotify import (interview evidence).
- Analytics pipeline (`track`, `analytics_events`); crash reporting vendor (`N-ARCH` "To decide").
- `export-account` (GDPR access; **launch blocker**, not TestFlight blocker).
- Handle rename + 30-day hold; account deactivation ("Need a break?").
- Full Apple token revocation; Universal Links; image moderation API; server image transforms; dark/light theming and the design-token lock (design round, playbook §6).
- Real users, production writes, commercial TMDB/MusicBrainz licences (launch blockers, `R-IOS §9`).

---

## 7. Risks (ranked) and open decisions

### 7.1 Risks, ranked

| # | Risk | Why it matters | Mitigation in this plan |
|---|---|---|---|
| 1 | **v0 is big.** 19 slices for a solo, agent-built app. Playbook's Purse round found the first plan "about 3x too big" ([[playbook]] §5). | Long time to a usable TestFlight; review load (every slice touches 3+ files, so every slice needs Codex review under rule 1). | Core loop first (S01–S08 is a complete, demoable loop on email users). Every later slice is independent and can slip to v0.1 without blocking the loop. Independent review should attack scope first. |
| 2 | **Data leaks through `security definer` code.** `recommend`, request RPCs and storage policies bypass or extend RLS (`R-BE §1.10`, `§2.1`). | A wrong join leaks private settings (pay preference, city) or shows blocked users. | Definer functions return IDs + reason codes only; explicit `is_blocked`; pgTAP visibility matrix (blocked both directions × every read path incl. storage and `recommend`) is a done-criterion for S06, S11, S13. |
| 3 | **Apple dependency chain is parked.** D39 defers enrolment; D33 requires an Organization account (legal entity, D-U-N-S, website). | Blocks TestFlight distribution, Sign in with Apple on device, APNs on device, App Store Connect record. D-U-N-S lead time **[unverified, often weeks]**. | All slices are verifiable on simulator + staging without the account except S16 (device push), S17 (device Apple sign-in), S19. Those three sit at the end. Recommend starting enrolment before S15. |
| 4 | **Apple 1.2 UGC "filtering" for images.** D34 excludes a paid moderation API; `SensitiveContentAnalysis` cannot be the filter (`R-IOS §4.2`). | Beta App Review rejection. | Text blocklist trigger, report on every surface, auto-hide at 3 reporters, daily review, reportable seed item for the reviewer. OD-11. |
| 5 | **Local stack unavailable.** No container runtime (ticket 005); native runtime uses random ports that `AppConfiguration` and scripts reject; Realtime, Storage, Edge Functions untested locally; 8.7 GiB free disk (`R-BE §7.1–7.3`). | Slices S03+ need a live stack for integration tests. | CI is the arbiter (Docker on ubuntu); native runtime for pgTAP now; OD-9. Staging can host manual end-to-end checks. |
| 6 | **Email flow unknowns.** Built-in mailer 2/hour; confirm-by-code behaviour with `enable_confirmations = true` unverified; leaked-password protection plan availability unverified (`R-BE §4.2`). | Testers cannot sign up; flow rework. | Verify in S03 against local Mailpit first; custom SMTP is a staging prerequisite (OD-15). |
| 7 | **Taste signal is noise in v0.** Placeholder cards, provisional facets, no taxonomy owner (D21; ticket 007). | "Similar sense of pacing" reasons could be false; ranking quality judged on fake data. | `N-ALG` cold-start rule lowers taste weight; gate the `similar_taste` reason behind `app_config.show_taste_reasons` until facets are real [design]. |
| 8 | **Deletion keeps message bodies.** AD keeps sent messages as "Deleted user"; Apple's deletion guidance says deletion includes user-generated content shared with others (`R-IOS §3.3`); Notion proposes deleting messages 30 days after account deletion (`N-DM` Retention). | Possible 5.1.1(v) rejection; GDPR erasure exposure. | OD-7 asks the user to override the AD. |
| 9 | **Account deletion and Apple revocation** (TN3194; Supabase has no server-to-server endpoint) (`R-BE §4.4`). | Rejection risk; support confusion on re-sign-in. | Documented fallback in v0; full revocation as launch hardening. |
| 10 | **Third-party terms.** TMDB commercial licence, 6-month cache cap, attribution; SoundCloud "own content" carve-out; Bandcamp embed path unverified (`R-IOS §5`, `§6`). | Public-launch blocker, not TestFlight blocker. | Proxy + snapshot refresh; facade + link fallback; legal checks in launch gates. |
| 11 | **Undesigned screens.** Suki matches/requests, My Projects, request composer, email screens, delete account have no frames (FIG "Gaps"); D26 makes the agent design them. | Rework after the design round. | Build them on placeholder tokens from existing components; prototype ticket 009 precedes S07. |
| 12 | **Chat reliability unproven** (Postgres Changes + RLS + reconnect not exercised against this schema; `R-BE §8.1` item 10). | Missed messages feel broken. | Table is source of truth; refetch on (re)connect/foreground; airplane-mode test in S08. |
| 13 | **Figma node IDs** in this concept come from the original file; D37 moves agents to copies. | Broken references in tickets. | Re-map IDs in the design round **[unverified that IDs carry over]**. |

**Locked decisions I would question (not re-opened, recorded per brief):**
- **D8/D31 up-front location and notification prompts.** Apple HIG prefers in-context requests and Core Location docs warn launch-time asks get denied (`R-IOS §2.1`); Notion defers both (`N-ARCH` Permissions). Cost: lower grant rates, some review risk. The primers, manual-city fallback and non-blocking denial keep it compliant.
- **D35 real APNs push in v0.** Adds an Edge Function, an outbox, a webhook and a key, and cannot be verified on device until D39 is lifted. In-app badges plus Realtime would prove the loop sooner. Kept, sequenced late (S16).
- **D21 taste cards in v0 with placeholders.** Builds UI and maths whose output is meaningless until facets and rights exist (Risk 7). Kept; facet weights and reasons are config so nothing is rebuilt later.
- **D33 Organization account + D39 deferral.** Together they put TestFlight on the critical path of a legal process (Risk 3).
- **AD "messages remain as Deleted user"** (Risk 8). This one is an agent default, so it is offered as OD-7 rather than only flagged.

### 7.2 Open decisions (lettered options, my recommendation first in bold)

| # | Decision | Options | Recommendation and why |
|---|---|---|---|
| OD-1 | Scoring formula inside SQL `recommend` | **A) Notion v1 components + harmonic-mean reciprocity + 0.35 threshold** (`N-ALG`); B) research additive integer points (`R-BE §2.4`); C) full Notion (Edge Function + pgvector) | **A.** It is the owner's spec, deterministic and explainable, and fits D15 once pgvector/Edge Function are dropped. Closes ticket 008 with Notion's weights as defaults. |
| OD-2 | Group chat per project | **A) Direct chats only in v0**; B) project group chat | **A.** D11 only needs pair chat; groups add membership sync and Realtime filters. Figma has no group screens. |
| OD-3 | Email verification | **A) 6-digit code right after sign-up (blocks onboarding ~1 min)**; B) link, non-blocking until request/publish (`N-ONB` Auth 1; needs universal links + domain); C) no verification on staging | **A.** No domain or universal links needed; matches `enable_confirmations = true`. Deviates from Notion's "does not block onboarding". |
| OD-4 | City on other people's profiles | A) private, per `N-DM` (`profile_settings`); **B) public city label** (Figma profile shows "Berlin, DE"; reason "Both in {city}" reveals it anyway) | **B.** Needs your explicit OK because it overrides Notion. Until answered, build A. |
| OD-5 | Staging app identity | **A) One App Store Connect app `club.kizuki.ios`; Staging config uses it, backend flips at launch**; B) separate `club.kizuki.ios.staging` app (current repo) | **A.** One App ID, one set of capabilities, one Apple provider config. Keychain keys are already per environment. |
| OD-6 | Auto-hide threshold | **A) 3 distinct reporters**; B) 2; C) 5 | **A.** D34 says "several"; 2 is easy to brigade, 5 is slow for a small alpha. |
| OD-7 | Deleting an account: sent messages and owned projects | A) keep messages as "Deleted user" (AD), delete projects; **B) delete projects; keep message rows but erase bodies 30 days after deletion** (`N-DM` retention); C) delete everything immediately | **B.** Aligns with Apple's deletion guidance and Notion retention while keeping threads coherent for 30 days. Overrides an AD. |
| OD-8 | Likes | **A) Private signal, no public counts**; B) public counts | **A.** `N-ALG`: never rank on popularity; Notion excludes public ratings. |
| OD-9 | Local runtime | **A) OrbStack or Colima (ticket 005)**; B) native runtime + port patches in `AppConfiguration` and scripts | **A.** Matches CI and fixed ports; B is the fallback if disk/licensing blocks A. |
| OD-10 | Message edit/unsend | **A) Neither in v0**; B) unsend within 15 min (`N-DM` "no edits after 15 minutes") | **A.** Smallest policy; reports keep evidence. Product Requirements asks for a documented policy: this is it. |
| OD-11 | Image filtering within D34 | **A) Report + auto-hide + daily review + text blocklist**; B) new photos hidden until reviewed | **A** for staging; revisit B if Beta App Review objects. |
| OD-12 | Compensation filter for People | **A) Hide a paid-seeking person only from viewers whose published projects are all unpaid**; B) no filter for people | **A.** Mirrors D3 without hiding people from viewers with no project (`R-BE §2.3`). |
| OD-13 | Default project expiry | **A) 30 days from publish, renewable**; B) 14 days; C) owner must pick | **A** [design]. Notion requires an expiry date but gives no default. |
| OD-14 | What Suki "Matches" shows | **A) Accepted requests (your connections), each opening its chat**; B) top recommendations (duplicates Home) | **A.** Home already holds recommendations (D19). Least-sure item; prototype ticket 009 should test it. |
| OD-15 | Email sender and support contact | A domain + SMTP provider (e.g. kizuki.club **[unverified ownership]**) and a support address | Needed before any staging sign-up and for MusicBrainz User-Agent, privacy policy, App Store support URL. User to supply. |

---

## 8. Phased build plan (tracer-bullet slices)

### Plain language

Nineteen small pieces. Each one works end to end and can be tested on its own. The first eight make the whole core loop real for an email user: sign up, onboard, publish a project, see it recommended, request, accept, chat. Everything after that widens the app around a loop that already works.

### Rules for every slice

- Each slice = one build ticket on the Wayfinder map (`docs/map/tickets/NNN-<slug>.md`; proposed numbers 012–030).
- Done = pgTAP tests (backend), Swift Testing (logic), one XCUITest flow on fixtures (UI), screenshots via the launch-argument router, CI green.
- **Wave 0 first** ([[playbook]] §7): S01 and S02 freeze Swift models, repository protocols, enums and RPC signatures; an independent agent checks the contracts before parallel lanes start.
- Lanes in parallel only with no overlapping files (iOS vs `supabase/`), max 3 at once ([[playbook]] §8).
- **Playbook rule 1:** anything touching auth, deleting data, money or 3+ files needs Codex cross-model review before merge. Every slice below changes 3+ files, so **every slice needs Codex review**. Column "Risk class" marks the ones where a miss is most costly: **AUTH**, **DELETE**, **PRIVACY** (definer code, RLS, storage policies), **ENV** (remote environments, secrets).

### Slices

| ID | Ticket | Slice (end-to-end test) | Depends on | Blocked by HITL | Risk class |
|---|---|---|---|---|---|
| S01 | 012 | **Contracts, fixtures, app shell.** Core models + repository protocols for every section-4 entity, `KizukiError` codes, `KizukiTestSupport` fixtures (one shared dataset), `Dependencies`, `AppRouter`/`AppRoute`, 5-tab `TabView` with placeholder roots, Home top bar (Inbox, Settings), launch-arg screen router; move `UITestBackend`; drop global dark lock. *Test:* UI test visits every tab and pushes every route on fixtures. | — | — | 3+ files |
| S02 | 013 | **Backend baseline + seed skeleton.** Enums; taxonomies (roles, project types, cities, facet catalog, blocked terms) in migrations; `private` schema + `is_blocked` + `blocks`; profile/settings extensions; `legal_acceptances` + `accept_terms`; handle 3–20 + `handle_available`/`set_handle`; text-filter trigger; `scripts/generate-seed.py` (20 users first) + `[db.seed]` on + abort guard. *Test:* pgTAP for every policy incl. blocked pairs; CI `local-backend`. | — | 005 for local runs (CI works now) | PRIVACY |
| S03 | 014 | **Email auth.** Sign-up (10+ chars), 6-digit verify, sign-in, sign-out, resend; custom email templates in `config.toml`; `SupabaseAuthRepository`; `rootPhase`. *Test:* XCUITest on Local with Mailpit code; seeded password user sign-in. | S01, S02 | 005 (or native runtime patch) | AUTH |
| S04 | 015 | **Onboarding core (no taste).** Handle, terms/18+, realm, intent, roles, Start/Join/Explore branches, availability, location + notification primers (permission only), work mode + city, `save_onboarding_step`, `complete_onboarding`, resume. *Test:* UI tests for three paths, resume after relaunch, permission-denied paths. | S03 | — | AUTH (gating) |
| S05 | 016 | **Projects + My Projects.** `projects`, `project_roles`, `project_members`, publish/close/reopen/renew RPCs, publish CHECK + role trigger, expiry cron + lazy filter; create form, detail (owner/visitor), My Projects segments. *Test:* pgTAP state machine incl. illegal transitions; UI create → publish → listed. | S04 | — | PRIVACY |
| S06 | 017 | **`recommend` v1 + Home feed.** `ranking_weights`, `app_config`, `recommend` (Stage 0 + R/L/I/F components; T neutral 0.5 until S09), bands, reasons, `recommendation_sets/items`; Home sections, Finish-your-project card, card overflow, `record_feedback` (like/save/hide/not my style). *Test:* pgTAP golden fixtures (expected IDs, order, reasons, block and compensation exclusions); UI shows seeded cards. | S05 | — | PRIVACY |
| S07 | 018 | **Requests + Suki.** `requests`, `request_decline_reasons`, send/respond/withdraw RPCs, transition trigger, duplicate index, rate limits, expiry; composer (join, collaborate, invite); Suki: Requests in/out, request detail, Matches (OD-14), Create chooser entry. *Test:* pgTAP full transition matrix + side effects; UI send as user A, accept as user B (fixture switch). | S05 (S06 for entry from Home) | 009 prototype review recommended first | 3+ files |
| S08 | 019 | **Chat (closes the core loop).** `conversations`, `conversation_participants`, `messages` RLS, Realtime publication, `ChatTransport` (Postgres Changes), Inbox list, chat screen, unread via `last_read_at`, report/block entry in header. *Test:* pgTAP insert policy (non-participant, closed, blocked); two-client integration on local stack; reconnect refetch. | S07 | 005 for local Realtime | PRIVACY |
| S09 | 020 | **Taste cards + pairwise.** `taste_items`, `taste_item_facets`, `taste_pairs`, selections, answers, `taste_facets`, `submit_taste` maths, placeholder art generator, `taste-cards` bucket (enables Storage); O4–O8 screens; switch on T in `recommend`. *Test:* pgTAP facet maths vs hand-computed values; UI picks 3 cards + 3 pairs. | S04, S06 | 007 for real facets (provisional set unblocks) | 3+ files |
| S10 | 021 | **Favourites.** `tmdb-proxy` Edge Function (enables edge runtime), MusicBrainz client (1.1 s queue, UA), `favourites`, picker in onboarding and profile edit, `shared_favourite` reason, TMDB attribution. *Test:* Deno tests (proxy, throttle); Swift tests (queue, decoding); pgTAP overlap. | S04 | TMDB API key; OD-15 contact for UA | ENV (secret) |
| S11 | 022 | **Storage, collab photos, Search.** Buckets + `storage.objects` policies, client renditions + EXIF strip, avatar upload, project covers, `collab_photos`, Post-a-collab flow, Search grid/chips/query/post viewer, signed-URL batch + path-keyed cache. *Test:* pgTAP storage policies incl. blocked pair and hidden photo; UI post → appears in grid. | S05 | 005 for local Storage | PRIVACY |
| S12 | 023 | **Profile + embeds.** Own/other profile, edit, `portfolio_sources` + host allow-list trigger, `KizukiEmbeds` parser, facade, locked `WKWebView` player (YouTube Referer, SoundCloud, Bandcamp), link chips. *Test:* parser unit tests (allow-list, hostile URLs); UI edit → link appears. | S11 | — | 3+ files |
| S13 | 024 | **Safety.** `reports`, `submit_report` with snapshot, auto-hide trigger, `block_user` side effects, unblock, blocked list, report sheet on every surface, restrictive-policy audit across all tables. *Test:* pgTAP both-directions matrix on every read path (profiles, projects, photos, favourites, links, requests, messages, storage, `recommend`). | S07, S08, S11, S12 | — | PRIVACY |
| S14 | 025 | **Settings, legal, support.** Settings root, notifications status + open-settings, privacy & safety, legal links, support contact, TMDB credit, sign out. *Test:* UI. | S13 | OD-15 (support URL) | 3+ files |
| S15 | 026 | **Delete account.** `delete-account` Edge Function, set-null/erase migrations (OD-7), re-auth, UI, Apple fallback copy. *Test:* Deno test on local stack (objects removed, user gone, messages per OD-7); pgTAP cascades; UI returns to entry. | S11, S14 | — | **DELETE + AUTH** |
| S16 | 027 | **Push.** `device_tokens`, `notification_outbox` triggers, DB webhook, `send-push` Edge Function, token registration, tap routing. *Test:* pgTAP outbox rows per event; Deno test with mocked APNs; device test. | S07, S08 | **D39 Apple account + APNs key** for device verification | ENV (secret) |
| S17 | 028 | **Sign in with Apple.** Nonce flow, staging provider config, first-sign-in name capture, account-linking check. *Test:* unit test nonce; device sign-in. | S03 | **D39** (App ID capability) | **AUTH** |
| S18 | 029 | **Full seed + staging deploy.** Seed to `R-BE §6.2` volumes covering every state edge, `seed-storage.py`, MANIFEST, staging push script with ref guard (`ankgfqkgflcalmlreetu` only, refuses production), `Staging.xcconfig` URL + key, smoke test against staging. *Test:* CI seed drift check; staging smoke checklist. | S02…S16 (grows with each) | Staging publishable key (D38), SMTP (OD-15) | **ENV** |
| S19 | 030 | **Release plumbing + TestFlight.** `PrivacyInfo.xcprivacy`, `ITSAppUsesNonExemptEncryption`, purpose strings, entitlements, App Store Connect record, privacy answers, review notes, demo account, archive/upload script. *Test:* archive validates; internal TestFlight install. | All | **D39**, D33 | ENV |

### Dependency graph (summary)

```
S01 ─┐
S02 ─┴─► S03 ─► S04 ─► S05 ─► S06 ─► S07 ─► S08      (core loop complete)
                 │      │      │      │      │
                 │      │      └─► S09 (with S04)
                 ├─► S10
                 │      └─► S11 ─► S12 ─┐
                 │                      ├─► S13 ─► S14 ─► S15
                 │      S07,S08 ────────┘
                 └─► S17 (S03)          S07,S08 ─► S16
           everything ─► S18 ─► S19
```

Critical path: S01/S02 → S03 → S04 → S05 → S06 → S07 → S08 → S13 → S14 → S15 → S18 → S19. Parallel lanes available after wave 0: iOS-heavy (S01, S04 UI, S12 UI) vs backend-heavy (S02, S05–S07 SQL, S13 policies), max 3.

---

## 9. Screen list per tab (structure only, no look)

Figma refs are nodes in the walkthrough (original file; see D37 note). "NEW" = no Figma frame; designed in SwiftUI from existing components (D26). Every list screen has loading, empty and error states (FIG gap 13).

**Entry and onboarding (before tabs)**
1. Splash (FIG `1312:11087`…)
2. Welcome / Create account / Log in (`1526:4399`)
3. Sign-in method: Apple + email (`1312:11854`, Google removed — D13, D28)
4. Email sign-up (email, password) — NEW (old App/draw `1013:6750` as reference)
5. Email log-in + forgot password — NEW
6. Verify email (6-digit code, resend) — NEW
7. Handle + display name (`1480:4256` minus age block; error states `1480:4367`)
8. Terms + 18+ checkbox (`1480:4256` age block, reworded per `N-ONB` Auth 3) and under-18 stop screen — NEW
9. Welcome O1 — NEW copy (`N-ONB`)
10. Realm O2 (`1312:11455` family)
11. Intent O3 (`1312:12209` family)
12. Taste cards O4 (intro `iPhone 16 Pro - 174`; picker NEW)
13. Pairwise choice O5–O7 — NEW
14. Serendipity O8 — NEW
15. Roles O9 (`1336:16105`)
16. Start: project type, roles needed, compensation (`1336:15975` + NEW)
17. Join: project interests, compensation preference — NEW
18. Explore: discovery focus — NEW
19. Availability C1 — NEW (App/draw `850:4200`)
20. Location primer (single Continue) (`1312:13188`, buttons replaced per D31)
21. City search / manual city — NEW
22. Work mode C2 (`1312:12351` partly)
23. Notifications primer (single Continue) — NEW (FIG gap 6)
24. Favourites picker (films / music) — NEW
25. Your work C3 (links, relation, two consents) (`1312:12814`)
26. Profile photo (`1312:12172`, `1312:11996`)
27. Building your space loader (`1312:11134`…)
28. Preview C4 / empty state (`1312:11364`)

**Tab 1 — Home**
1. Home feed: Finish-your-project card, Recommended projects, People you might like (`1312:8064`, `1467:4643`)
2. Project detail (visitor) with roles, collaborators, Ask to join (`1485:5384`, `1449:4691`; "Create a collab" CTA retargeted to the request composer)
3. Person card → Profile (other) (shared with Profile tab screen 2)
4. Request composer sheet (role picker, message) — NEW (FIG gap 3)
5. Missing-fields sheet (one sheet, only missing fields) — NEW
6. Inbox: conversation list (`1312:10492`, `1312:10709` without "New message" and message-requests folder — D11, D28)
7. Chat (project context header, Report, Block, closed state) (`1312:10374`)
8. Settings root (`1312:8654`) → Account (sign out, delete account), Notifications, Privacy & Safety (blocked accounts; "Who can message me" removed), Help & Support, Legal & About (TMDB credit) (`1312:8799`…`1312:9294`; sign-out, delete, blocked list NEW)
9. Delete account: explain → re-auth → confirm → done — NEW
10. Blocked accounts list — NEW
11. Report sheet (category, context, confirmation + Also block) — NEW (shared across tabs)

**Tab 2 — Search**
1. Search grid with chips (`1312:9342`, `1468:5306`)
2. Query results: photos + people row (`1312:9406`)
3. Post viewer (`1473:5533`, `1473:5636`)
4. No-results state — NEW

**Tab 3 — Suki** (D19: matches, requests, create)
1. Suki home: Matches / Requests / Create segments — NEW (landing art `1361:12184` as Create empty state)
2. Matches list (accepted connections → chat; OD-14) — NEW
3. Requests: Incoming / Sent lists with status — NEW
4. Request detail (who, project/role, message, fit reasons, Accept / Decline / Report / Block; sent view: Withdraw) — NEW
5. Decline sheet (optional private reason) — NEW
6. Create chooser: New project / Post a collab (`1361:12435` family; labels unverified)
7. New project form (`1361:12567`, payments/"Paid: Yes" toggle replaced by compensation label)
8. Post a collab: photo picker → caption + tags → preview (`1488:6338`, `1385:9327`, `1418:3318`)

**Tab 4 — My Projects** (all NEW; FIG §8 gap)
1. My Projects: Drafts / Published / Past segments
2. Project detail (owner): Edit, Publish, Close, Mark done, Renew, Invite, roles with filled state, members
3. Project editor (reuses Suki form)
4. Invite sheet (pick person from Matches/recommendations, pick role)
5. Publish error state (field list)

**Tab 5 — Profile**
1. Own profile: header, roles, bio, favourites, links/embeds, collab photos, projects, Edit (`1312:10251` own-empty; `1312:9852` layout minus Follow/followers — D24)
2. Other profile: same + Ask to collaborate + overflow Report/Block (`1312:9852`, `1312:10050`, `1312:10189`)
3. Edit profile: name, bio, avatar, realms, roles (`1418:3514` family)
4. Edit links: add URL → relation → consents (`1423:11185`)
5. Embed player sheet (YouTube / SoundCloud / Bandcamp) — NEW
6. Edit favourites (picker reuse)

---

## 10. Diagram specs for Archify (one per diagram)

Each spec is self-contained for one Sonnet agent ([[playbook]] §5 "one agent per diagram"). No colours or fonts; use Archify defaults. Labels in plain language; technical names in node subtitles.

### 10.1 System overview (architecture diagram)

- **Groups:** `Device` (iPhone app); `Supabase staging` (Auth, PostgREST + RLS, RPC functions, Realtime, Storage, Edge Functions, pg_cron); `Apple` (Sign in with Apple, APNs); `Third parties` (TMDB, MusicBrainz, YouTube/SoundCloud/Bandcamp players).
- **Nodes:** iOS app (subtitle "SwiftUI · KizukiKit"); Auth; Postgres (subtitle "RLS on every table · is_blocked"); RPC functions (subtitle "requests · publish · recommend · block · report"); Realtime ("Postgres Changes on messages"); Storage ("avatars · collab-photos · project-covers · taste-cards"); Edge: delete-account; Edge: send-push; Edge: tmdb-proxy; notification_outbox (table); pg_cron ("expire projects hourly, requests daily"); Sign in with Apple; APNs; TMDB; MusicBrainz; Embed players.
- **Edges:** app → Auth "sign in (Apple token / email)"; app → Postgres "reads + own writes"; app → RPC "state changes"; RPC → Postgres; app ↔ Realtime "new messages"; Realtime → Postgres "listens"; app → Storage "upload / signed URLs"; app → delete-account "delete my account"; delete-account → Storage "remove files"; delete-account → Auth "delete user"; Postgres triggers → notification_outbox; outbox → send-push "database webhook"; send-push → APNs; APNs → app "push"; app → tmdb-proxy → TMDB; app → MusicBrainz "direct, 1 req/s"; app → Embed players "on tap only"; app → Sign in with Apple; pg_cron → Postgres.
- **Callout:** "Production project enosggckdxjiaqtxalhg: not used in v0" as a detached, greyed node.

### 10.2 Main user flow: request → accept → chat (sequence diagram)

- **Lanes (participants):** Ana (sender, iPhone); Database (RPC + RLS); Push (outbox + send-push + APNs); Ben (recipient, iPhone).
- **Steps:**
  1. Ana → Database: "Ask to join: role Editor, message" (`send_request`).
  2. Database: checks "onboarded · email verified · not blocked · no duplicate · role open · pay compatible · under daily limit" (note box).
  3. Database → Database: "request = pending"; "outbox row".
  4. Push → Ben: "New request from @ana".
  5. Ben → Database: "Open request" (read via RLS).
  6. Ben → Database: "Accept" (`respond_request`).
  7. Database: one transaction note: "request = accepted · conversation created · both added · Ana joins project · role filled".
  8. Push → Ana: "@ben accepted your request".
  9. Ana → Database: "Send message" (insert, client_id).
  10. Database → Ben: "Realtime: new message"; Push → Ben "New message from @ana" (if not in chat).
- **Alt frames:** "Decline" (status declined, private reason, no chat); "Blocked" (send rejected with `blocked`); "No answer in 14 days" (expired).

### 10.3 Request state machine (state diagram)

- **States:** Start (pseudo); Pending; Accepted (final); Declined (final); Withdrawn (final); Expired (final).
- **Transitions:** Start → Pending "send (sender)"; Pending → Accepted "accept (recipient)"; Pending → Declined "decline (recipient)"; Pending → Withdrawn "withdraw (sender)"; Pending → Withdrawn "block (either)"; Pending → Expired "14 days pass"; Pending → Expired "project closed / role filled".
- **Notes:** on Accepted: "chat opens · member added · role filled · push to sender". On finals: "no further changes (database trigger)". Side note: "Three kinds: ask to join · ask to collaborate · invite — same states".
- **Second panel (small):** Project status machine: Draft → Published "publish"; Published → Closed "filled / closed by owner"; Closed → Published "reopen"; Published → Past "expired / done"; Past → Published "renew"; Draft → (deleted) "delete". Note "Hidden by moderation applies to any state".

### 10.4 Data model (ER diagram)

- **Groups and entities (with 3–5 key fields each):**
  - *Who you are:* profiles (id, handle, primary_realm, onboarding_completed_at); profile_settings (private: intent, availability, work_mode, city, compensation_preference); legal_acceptances; profile_roles; favourites; portfolio_sources; device_tokens.
  - *Taxonomy:* roles, project_types, cities, facet_catalog.
  - *Taste:* taste_items, taste_item_facets, taste_pairs, taste_seed_selections, pairwise_answers, taste_facets.
  - *What you make:* projects (owner_id, status, closed_reason, compensation_status, expires_at); project_roles (status open/filled); project_members; collab_photos.
  - *How you connect:* requests (kind, sender_id, recipient_id, project_id, status); request_decline_reasons; conversations; conversation_participants; messages; notification_outbox.
  - *Safety:* blocks; reports.
  - *Matching:* recommendation_feedback; ranking_weights; recommendation_sets; recommendation_items.
- **Relationships (crow's foot):** profiles 1–1 profile_settings; profiles 1–N profile_roles N–1 roles; profiles 1–N favourites, portfolio_sources, collab_photos, legal_acceptances, device_tokens, taste_facets; profiles 1–N projects (owner); projects 1–N project_roles N–1 roles; projects 1–N project_members N–1 profiles; requests N–1 profiles (sender), N–1 profiles (recipient), N–1 projects, N–1 project_roles, 0..1–1 conversations; conversations 1–N conversation_participants N–1 profiles; conversations 1–N messages; profiles N–N profiles via blocks; reports N–1 profiles (reporter); taste_items 1–N taste_item_facets N–1 facet_catalog; recommendation_sets 1–N recommendation_items.
- **Visual markers:** badge "private (owner only)" on profile_settings, legal_acceptances, taste_*, device_tokens, request_decline_reasons; badge "RPC-only writes" on requests, conversations, project_members, blocks, reports; badge "service role only" on notification_outbox, recommendation_sets/items.

### 10.5 Build roadmap (timeline / swimlane)

- **Swimlanes:** iOS; Backend (SQL); Edge Functions; Environments & release; Human-in-the-loop.
- **Phases (left → right):** A Contracts (S01, S02); B Core loop (S03–S08); C Widen (S09–S14); D Account & platform (S15–S17); E Ship (S18, S19).
- **Items:** each slice as a card "Sxx · name · risk class", placed in its main lane; dependency arrows per section 8 graph. Milestone diamond after S08: "Core loop works end to end (email user, simulator)". Milestone after S18: "Staging seeded and smoke-tested". Final milestone after S19: "TestFlight".
- **HITL lane cards:** 005 container runtime (before S03); staging publishable key (before S18); SMTP + domain OD-15 (before S03 on staging, S18); TMDB key (before S10); Apple Developer enrolment D39 + APNs key (before S16 device test, S17, S19); 009 Suki/My Projects prototype review (before S07); 007 taste facets (improves S09).
- **Badge:** "Codex review required" on every slice; stronger badge on S15 (delete), S03/S17 (auth), S18 (environments).

---

## 11. Numbers that matter

| Number | Value | Source |
|---|---|---|
| Tabs | 5 (Home, Search, Suki, My Projects, Profile) | D19 |
| Build slices | 19 (8 to a working core loop) | This doc §8 |
| Edge Functions in v0 | 3 | This doc §2.3 |
| Tables in v0 | ~33 incl. taxonomy and logs | This doc §4.2 |
| Ranking weights R/T/L/I/F | 0.30 / 0.25 / 0.20 / 0.15 / 0.10 (+0.05 complementarity) | `N-ALG` Part 2 |
| Show threshold | reciprocal score ≥ 0.35 | `N-ALG`, `N-RS` |
| Minimum results before empty state | 3 | `N-ONB` C4, `N-RS` |
| Reasons per card | 2–4 | `N-ONB` C4, `N-ALG` |
| Serendipity mix | 80/15/5, 60/30/10 (default), 40/40/20 | `N-RS` |
| Exposure floor | 1 slot in 10 for creators < 14 days, < 20 impressions | `N-ALG` |
| Max items per owner per set | 2 | `N-RS` |
| Recommendation latency budget | < 400 ms p95 whole call | `N-ALG` (unmeasured) |
| Taste cards | 12 shown, pick 3–5, ≥ 24 per realm | `N-ONB` O4 |
| Pairwise choices | 3 required + up to 2 follow-ups | `N-ONB` O5–O7 |
| Facet taxonomy | target 60–120 values; v0 provisional ≈ 30 | `N-ALG` Part 1; [design] |
| Roles per profile | 1–3, one primary | `N-ONB` O9 |
| Handle length | 3–20 chars | AD (existing migration 3–24) |
| Password minimum | 10 chars + breach check | `N-ONB` Auth 1 |
| Request rate limit | 5/day (account < 7 days), 20/day otherwise | `N-BF` |
| Report rate limit | 10/day | `N-BF` |
| Handle checks | 30/min | `N-BF` |
| Request expiry | 14 days | `N-BF` |
| Project default expiry | 30 days | [design] OD-13 |
| Auto-hide | 3 distinct reporters | [design] OD-6 (D34 "several") |
| Report review target | 24 h, daily | D34 |
| Message length | 1–2000 chars | `R-BE §1.6` [design] |
| Request message | ≤ 500 chars | `R-BE §1.5` [design] |
| Bio / caption / project-type other | ≤ 280 / ≤ 140 / ≤ 40 | `R-BE §1.3`, §1.7; `N-ONB` S1 |
| Collab photos per user | ≤ 24 | `R-BE §1.7` [design] |
| Favourites | ≤ 5 per kind | `R-BE §1.4` [design] |
| Upload limits | avatar 1 MB; photos/covers 2 MB; renditions ~400 px / ~1600 px | `R-BE §5.1`, §5.3 [design] |
| Signed URL TTL | ~1 h | `R-BE §5.3` [design] |
| Built-in email sending | 2 emails/hour/project → custom SMTP required | `R-BE §4.2` (Supabase docs) |
| Auth endpoint rate | 30 requests / 5 min / IP | `R-BE §4.2` |
| Realtime free plan | 200 concurrent connections, 100 msg/s | `R-BE §3.2` |
| Edge Function limits | 2 s CPU, 256 MB, 150 s wall (free) | `R-BE §2.1` |
| JWT expiry (local) | 3600 s | repo `supabase/config.toml` |
| MusicBrainz | 1 request/s per IP; UA with contact required | `R-IOS §6.2` |
| TMDB | ~40 req/s; cache ≤ 6 months; non-commercial free | `R-IOS §6.1` |
| Seed volume | 60 users, 25 projects, 30 requests, 6 conversations / ~90 messages, 90 photos, 96 taste cards | `R-BE §6.2` [design] |
| Native runtime cache / free disk | 1.8 GB / 8.7 GiB | `R-BE §7.3`, §8.1 (measured 2026-10-25) |
| Existing tests | 21 Swift tests + 2 UI tests (count of `@Test`/`func test`); 10 pgTAP | repo grep 2026-10-25; `R-BE §7.3` |
| TestFlight | 100 internal, 10,000 external testers; builds expire after 90 days | `R-IOS §8.1` |
| Apple Developer Program | USD 99/year | `R-IOS §8.1` |
| Quality bar | cold start < 2 s (iPhone 12); crash-free ≥ 99.5% before widening beta | `N-ARCH` |
| Users / cost / traffic at launch | **TBD** | no source; v0 is mock data only |
| Supabase staging plan (Free vs Pro) | **TBD** | D38 does not say; affects image transforms, leaked-password protection, PITR |

---

## Appendix A — Reconciliation log (locked decisions / Notion / research / Figma)

Notion was reachable on 2026-10-25; all four canonical pages were read ([[2026-10-25-notion-technical-extracts]]). Rule applied: locked decision or AD → Notion → research → Figma. "Kept" = what this concept does.

| # | Topic | Notion | Research lane | Locked / AD | Kept | Why |
|---|---|---|---|---|---|---|
| 1 | Where scoring runs | Stage 0–1 SQL, Stage 2–3 TypeScript Edge Function, pgvector (`N-ALG`, `N-BF`) | SQL RPC (`R-BE §2.1`) | D15 "rule-based scoring in Postgres" | SQL RPC | D15 |
| 2 | Scoring formula | 5 weighted components, harmonic-mean reciprocity, 0.35 threshold (`N-ALG`) | Additive integer points, threshold 30 (`R-BE §2.4`) | D15 silent on formula | Notion formula in SQL | Notion over research (OD-1) |
| 3 | pgvector `taste_vectors` | Yes, HNSW (`N-DM`) | Not needed v0 (`R-BE §2.6`) | D15 "simple" | Deferred; plain SQL cosine | D15; scale |
| 4 | MMR, jitter, re-fit, weak ties | Yes (`N-ALG`) | n/a | D15 "simple" | Deferred | Determinism for tests |
| 5 | `send/respond-request`, `publish-project`, `complete-onboarding` | Edge Functions (`N-BF`) | SQL RPCs (`R-BE §1.5`) | none | SQL RPCs; push via outbox webhook | Transactional, testable, no service role needed |
| 6 | Realm value for mixed | `mixed_practice` | `mixed` | none | `mixed_practice` | Notion over research |
| 7 | Compensation enums | preference (paid/unpaid/either) + status (+undecided) | single `compensation` incl. open_to_either | D3 semantics | Notion's two enums | Notion |
| 8 | Project statuses | draft, published, filled, closed, expired, hidden | 4 + closed_reason | AD: 4 statuses + `closed_reason` | AD; `hidden_at` column for moderation | AD overrides |
| 9 | Project roles | `status` open/filled, one row per role | `slots`/`filled` counts | none | Notion (one row per seat) | Notion; simpler |
| 10 | Private vs public logistics | city, work_mode, availability, compensation in private `profile_settings` | city/work_mode/availability public on `profiles` | none (Figma shows city) | Notion (private) until OD-4 | Notion over research/Figma |
| 11 | Consent table name | `legal_acceptances` | `profile_consents` | none | `legal_acceptances` | Notion |
| 12 | Links | `portfolio_sources` with two consents | `profile_links` | D23 | `portfolio_sources` | Notion |
| 13 | Favourites / references | Shared `references` catalogue + `profile_references` | Per-profile `favourites` snapshot | D22 TMDB/MusicBrainz | Per-profile `favourites` | Client-supplied titles in a shared catalogue = cross-user text injection; `references` is an SQL reserved word; catalogue deferred |
| 14 | Card facet weights | `taste_items.facet_ids text[]` (no weights) | `taste_card_facets(weight)` | none | `taste_item_facets(weight)` | `N-ALG` itself needs per-card weights; Notion DM can't hold them |
| 15 | Profile taste store | `taste_facets` per profile | `profile_taste(score)` | none | Notion name, columns `signal_sum`, `evidence_count` per `N-ALG` | Notion |
| 16 | `response_ms` | Store, research only | Drop | none | Store nullable, never read | Notion over research |
| 17 | Feedback | `recommendation_feedback`, no `like` | `item_feedback` incl. like | D25 likes | `recommendation_feedback` + `like` | Notion name; D25 |
| 18 | Request duplicates | Pending only | Pending + accepted | none | Pending + declined (same sender, recipient, project) | Anti-harassment [design]; flagged for review |
| 19 | Decline reason | Column on `requests` | Private column | Product Requirements "private" | Separate `request_decline_reasons` table | RLS cannot hide one column per viewer |
| 20 | Invites | Not in DM | `invite_to_project` kind | D36 | `request_kind` incl. invite | D36 |
| 21 | Conversation per | accepted request | per pair + project groups | D11 | Per pair, direct only | OD-2 |
| 22 | Message edits | "No edits after 15 minutes" | soft delete | none | No edit, no unsend | OD-10 |
| 23 | Message read state | `read_at` per message | `last_read_at` per member | none | `last_read_at` | Cheaper; group-ready |
| 24 | Message retention after deletion | Delete 30 days after account deletion | set null | AD keep as "Deleted user" | AD now; OD-7 recommends Notion | Apple deletion guidance |
| 25 | Permissions timing | Notifications after first request; location only on Near me (`N-ARCH`) | Up-front primers compliant | D8, D31 up front | Up front with primers | Locked |
| 26 | Sign-in methods | Apple, Google, email/password | OTP recommended | D13, D30 Apple + email/password | Apple + email/password | Locked |
| 27 | Email verification | Link, non-blocking until request/publish | OTP code | none | Code after sign-up, blocking | OD-3 |
| 28 | Navigation | Discover/Projects/People/Inbox/You | Home/Search/Suki/MyProjects/Profile | D19, D32 | D19 | Locked |
| 29 | Moderation | Queue, actions, appeals; never auto-ban | Dashboard review | D16, D34 dashboard + auto-hide | Auto-hide (not ban) + dashboard | Locked |
| 30 | Analytics `track` | MVP Edge Function | No analytics SDK | none | Deferred | v0 = mock data; no users to measure |
| 31 | `validate-link`, recheck | Edge Function + weekly job | Drop for v0 | D23 | Client + DB allow-list; deferred | Scope |
| 32 | `export-account` | MVP | n/a | none | Deferred; launch blocker | Not needed for TestFlight with mock data |
| 33 | Avatar size | Max 1024 px | 1 MB bucket cap | D9 | Both | Compatible |
| 34 | Handle length | 3–24 | 3–24 (existing) | AD 3–20 | 3–20 | AD |
| 35 | Staging bundle ID | n/a | `club.kizuki.ios` (claimed) | D10 bundle `club.kizuki.ios` | Repo has `.staging`; OD-5 | Repo vs research disagree |
| 36 | Compensation for paid seekers | Callout "only paid" vs table "paid + either" (`N-ONB`) | Table | D3 paid + either | D3 | Locked |

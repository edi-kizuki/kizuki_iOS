---
title: Kizuki v0 architecture concept v2
created: 2026-10-25
version: 2
tags: [project/kizuki, architecture-round, concept, ios, supabase]
status: draft-for-verification
supersedes: 2026-10-25-architecture-concept-v1
---

# Kizuki v0 architecture concept v2

Related: [[playbook]], [[2026-10-24-architecture-round-1-interview]], [[2026-10-25-supabase-backend-research]], [[2026-10-25-ios-client-integrations-research]], [[2026-10-25-figma-full-walkthrough]], [[2026-10-25-wayfinder-map]]

Also: [[2026-10-25-architecture-concept-v1]], [[2026-10-25-concept-v2-changelog]], [[2026-10-25-concept-v1-review-claude]], [[2026-10-25-concept-v1-review-codex]], [[2026-10-25-notion-technical-extracts]], [[2026-10-25-design-tokens]], [[00-what-exists]].

**How to read this.** Plain language first in each section, technical detail after. Citations: `D#` = locked decision # in [[2026-10-24-architecture-round-1-interview]] (now 1–45). `OD-n (accepted)` = an open decision from v1 that the user accepted by default (interview "Agent recommendations accepted by default"). `AD:` = agent default in the interview. `N-DM`, `N-BF`, `N-ALG`, `N-ARCH`, `N-RS`, `N-TS` = Notion Data Model & RLS, Backend Functions & Jobs, Recommendation & Taste Algorithm v1, iOS Technical Architecture, Recommendation System, Trust & Safety ([[2026-10-25-notion-technical-extracts]]). `N-ONB` = Onboarding Spec v3.1 ([[2026-10-24-notion-source-extracts]]). `R-BE §x`, `R-IOS §x` = the two research notes. `FIG-V` = the "Visual pass (2026-10-25)" section of [[2026-10-25-figma-full-walkthrough]] (canonical file `nPqXTMCtd3OVZTSU7Y2uN3`, D37; node IDs are the same as the original file per that section's header). `C-xx` / `X-xx` = review findings (Claude / Codex); the changelog maps each one. **[unverified]** = not confirmed against a primary source or a running system. **[design]** = my recommendation, not a fact.

Precedence: locked decisions (incl. accepted ODs) → Notion → research → Figma. Disagreements are in Appendix A. **No colours or fonts are chosen here**; tokens live in [[2026-10-25-design-tokens]] and the design round.

## 0. Recommendation and what changed

### The one-line recommendation

Build v0 as **one native SwiftUI app (per-tab feature modules over a shared Core, fixtures first) on one Supabase schema where every rule that protects a user lives in Postgres** (RLS + narrowly-scoped `security definer` functions + row locks + triggers, all tested by pgTAP, two-connection race tests and a live API suite in CI), with three Edge Functions (`delete-account`, `send-push`, `tmdb-proxy`), Postgres Changes for chat, and a SQL `recommend` function implementing Notion's v1 scoring with a defined cold start. It runs against staging `ankgfqkgflcalmlreetu` with fictional data; TestFlight follows Apple enrolment (D38, D39, D43).

### What changed from v1 (summary; full mapping in [[2026-10-25-concept-v2-changelog]])

1. **Acceptance is authorized and serialized** (4.5): kind-specific seat binding, full re-validation at accept time, one global lock order, atomic seat claim, two-connection race tests.
2. **Conversations have generations** (2.6, 4.2): a block closes and hides the thread; a fresh accepted request after unblock opens a new one. Fixes the v1 dead end.
3. **Deletion is a server-side state** (4.7): `deleting` freezes writes and fails stale JWTs everywhere; D42's 30-day message-text erasure has a purge key and a job; Apple tokens are exchanged and revoked (verification waits on D39).
4. **Push has a trust boundary** (2.9): server-only secret, outbox ID only, single-owner tokens unlinked on sign-out, leased retries with dedupe, no environment secrets in migrations.
5. **Environments are pinned** (3): exact staging ref allowlist in the app, the build validator and every remote script; production builds and seeds are refused in v0 by two independent checks; a guard-compatible staging seed path exists.
6. **Privacy model and reasons agree** (2.10): city is public (D41); availability and work mode stay owner-only and never appear in person reasons.
7. **Cold start is defined** (2.10): no-taste viewers and candidates get neutral taste and the adjacent band, so Home is never empty because of missing taste.
8. **Tests prove the loop without a local Docker** (8.4): live backend tests run in the Linux CI job; recorded HTTP contracts bind the Swift repositories to that live behaviour on the macOS job.
9. **Build plan re-sliced** (8): 20 thinner slices, schema before consumers, safety moved up, every locked v0 feature in the exit criteria, no "can slip to v0.1" escape hatch.
10. **Scope cut where nothing locked requires it** (6): recommendation logging, serendipity mix and its onboarding screen, exposure floor, adaptive pairwise follow-ups, reopen, trigram search, "For you" chip, the third bucket.
11. **Late decisions applied**: "Crew" (D40, D44), public city (D41), D42 retention, one app `club.kizuki.ios` (D43), accepted ODs, visual-pass corrections (request form, Suki chooser, two-option goal screen, ratings and comments out).

What I am least sure of is in 7.3.

---

## 1. Problem, users, v0 destination

### Plain language

Creative people struggle to find collaborators whose taste and working conditions fit. Kizuki shows each person a small set of people and projects that fit both ways, says why, and lets them send a request. Chat opens only when the other person accepts, and accepted people become your **Crew**. v0 proves that loop on an iPhone, end to end, with fictional data.

### Detail

- **Promise.** "Find your people. Make something real." Matching on capability, taste, intent, availability, work mode/city, compensation and trust (Canonical Product Brief, via [[00-what-exists]]).
- **Users.** Individual creators: film/video, music/sound, visual arts, mixed practice. First cohort Berlin indie film and the collaborators those projects need (Canonical Product Brief). Adults only, 18+ (`N-TS` Minors).
- **Product loop.** Identity and intent → relevant people/projects → reasons → request → acceptance and conversation → collaboration → Made Together (brief). v0 stops at conversation; Made Together is out (interview "Out of v0").
- **v0 destination.** "Core loop v0 working end to end on mock data, native iOS on TestFlight: sign in (Apple or email) → onboarding (incl. taste cards) → Home feed → request → accept → chat, plus Search, Suki, My Projects and Profile. No target date; ship when it works." ([[2026-10-25-wayfinder-map]]; D1, D18, D19, D21). TestFlight distribution waits on Apple enrolment, deferred by the user (D39); everything else is reachable on simulator against staging.
- **Constraints.** iOS 17+, Swift 6 strict concurrency, SwiftUI, Observation (repo `project.yml`). Production `enosggckdxjiaqtxalhg` untouched (D10, D29). Staging `ankgfqkgflcalmlreetu`, mock data only (D38). One app `club.kizuki.ios` (D43). Five tabs Home/Search/Suki/My Projects/Profile, system icon-only `TabView`, Inbox and Settings in Home's top bar (D19, D32). Chat only after acceptance; requests both ways (D11, D36). No payments, follows, comments, ratings, events, Google, Made Together, appeals tooling (D12, D13, D24, D25; FIG-V conflicts 7–8).
- **Starting point (verified by both reviews).** KizukiKit with four targets, supabase-swift `exact: 2.55.4` + committed `Package.resolved`, `AppSession` with generation guard, PKCE + Keychain per environment, one migration with 10 pgTAP tests, 21 Swift `@Test` + 2 UI tests, CI with `ios` (macos-15, Xcode 26.0.1) and Docker-backed `local-backend` (ubuntu) jobs (review X "Existing-code claim audit"; C "Verdict").

---

## 2. Recommended design, end to end

### 2.0 Plain language

- **The app** is small feature modules, one per tab, that talk only to interfaces. Tests and previews use invented data; the real app calls Supabase.
- **The database is the rulebook.** Who sees what, who can message whom, what a block hides, how a request changes state, whether a deleted account can still act: all enforced in Postgres, so a buggy or hostile app cannot bypass them.
- **Three small server functions** do what the database cannot: delete an account (admin rights), send pushes (Apple's key), search films (keeps the TMDB key off the phone).
- **Matching is a transparent formula** that scores fit both ways, hides anything blocked or incompatible, and gives 2–4 plain reasons that never reveal private settings.
- **Chat** uses a live feed for new messages; the messages table is always the truth.

### 2.1 System overview

```
iPhone app (SwiftUI)
  ├─ Supabase Auth ─────── email + password (code verify, code recovery) / Apple ID token
  ├─ PostgREST (RLS) ───── reads + own-row writes (column-level grants)
  ├─ RPC (security definer, locked, idempotent) ─ onboarding, requests, projects, block, report, recommend
  ├─ Realtime ─────────── Postgres Changes on messages (filtered by conversation_id, RLS per event)
  ├─ Storage ──────────── avatars (public) · user-media (private: collab photos + project covers) · taste-cards (public read-only)
  ├─ Edge Function tmdb-proxy ──► TMDB
  ├─ Edge Function delete-account ──► Storage API + Apple token revoke + auth.admin.deleteUser
  └─ MusicBrainz (direct from device, 1 req/s queue)
Postgres triggers ──► notification_outbox ──► (fast path) pg_net call  ─┐
pg_cron every minute ──► drain due outbox rows via pg_net ───────────────┴─► send-push (server secret) ──► APNs
pg_cron ──► expire projects (hourly), expire requests (daily), erase deleted users' message text (daily),
            purge abandoned sign-ups (daily), resume stuck deletions (hourly)
```

Rule of thumb (`N-ARCH` System overview): the app reads through RLS and writes only its own simple rows; anything touching another user, ranking, an external service, a limit or a state machine goes through an RPC or Edge Function.

### 2.2 iOS client

**Modules** (one package, many targets; from `R-IOS §1.3`, 7 feature targets). Unchanged from v1 except as noted.

| Target | Owns | Depends on |
|---|---|---|
| `KizukiCore` (exists) | Domain models, repository protocols, `AppSession`, `SessionScope`, `AppRoute`/`AppTab`, state enums, `KizukiError` | — |
| `KizukiInfrastructure` (exists) | `Supabase*Repository`, `ChatTransport`, uploader, TMDB/MusicBrainz clients | Core, supabase-swift 2.55.4 |
| `KizukiPlatform` (new) | `LocationService`, `NotificationService` (permission, token register/unregister), `DeepLinkParser`, primer state | Core |
| `KizukiDesignSystem` (exists) | Components on placeholder tokens until the design round, `RemoteImage`, Blobatar `ProfileAvatar` | — |
| `KizukiEmbeds` (new) | Pure URL → embed descriptor (allow-list), facade, locked `WKWebView` | DesignSystem |
| `KizukiTestSupport` (new) | Fixtures + fake repositories; **every source file wrapped in `#if DEBUG`** so the Release product is empty; a release-build check fails if fixture symbols appear (C-34) | Core |
| `KizukiEntryFeature` | Sign-in, sign-up, verify code, password recovery, Terms/18+, handle, onboarding, primers, taste, favourites picker | Core, DS, Platform |
| `KizukiHomeFeature` | Feed, Finish-your-project card, project detail, request composer, Inbox, chat | Core, DS |
| `KizukiSearchFeature` | Grid, chips, query, post viewer | Core, DS |
| `KizukiSukiFeature` | **Crew**, Requests (incoming/sent), request detail, Create chooser (Get discovered / Create a project / Post a collab) | Core, DS |
| `KizukiMyProjectsFeature` | Drafts / Published / Past, owner project detail, editor, invite | Core, DS |
| `KizukiProfileFeature` | Own/other profile, edit, links/embeds, favourites | Core, DS, Embeds |
| `KizukiAccountFeature` | Settings, report sheet, block, blocked list, delete account, legal, support | Core, DS |

Features never import Infrastructure or each other; the App target composes (`R-IOS §1.3`).

**Routing.** `TabView(selection:)` with `.tabItem`/`.tag` (iOS 17), icon-only system bar (D32). One `NavigationStack(path:)` per tab; `@MainActor @Observable AppRouter`; `AppRoute` in Core (`.profile`, `.project`, `.request`, `.conversation`, `.inbox`, `.settings`, `.collabPhoto`, `.report`, `.crew`). Entry: `kizuki://` via `onOpenURL`; push `userInfo["route"]`. Launch-argument router for screenshot galleries ([[playbook]] §7). No universal links in v0 (2.8 removes the need).

**Session lifecycle (X-15).** The existing `AppSession` ignores a repeat `signedIn` for the same user and the `Profile` model has four fields (`AppSession.swift:73–75`, `Profile.swift:4–8`). v2 contract:
- `Profile` gains `onboardingCompletedAt`, `eligibleAt` (from `legal_acceptances`), `accountStatus`; `ownProfile` selects them.
- `AppSession.refreshProfile()` is public and is called by every mutation that changes root-relevant state (`accept_terms`, `complete_onboarding`, account deletion start). Root phase is derived: `entry` → `verifyEmail` → `passwordRecovery` → `eligibility` (Terms/18+) → `onboarding(step)` → `main` → `deleted`.
- Auth events: `passwordRecovery` is handled explicitly (today it falls into `default`, `SupabaseBackend.swift:36–50`).
- **`SessionScope`**: created per signed-in user with the existing generation number; owns every long-lived task (feeds, chat channels, upload queues). Account switch or sign-out cancels the scope; chat channels call `removeChannel` on disappear and on scope cancel; `AsyncStream` `onTermination` unsubscribes. Image cache is per scope and purged on sign-out (2.7).

**DI and state.** One `Dependencies` struct (protocol-typed repositories) built in the App target (`Live` or `Fixture` by launch argument in Debug only); models get dependencies via `init`. Observation only; `LoadState<T>` per async load; no TCA, SwiftData or offline queue (`R-IOS §1.4`, `§1.7`).

**Errors.** RPCs raise a fixed SQLSTATE with JSON `detail` `{code, fields?, retry_after?}`; Core maps to `KizukiError` (`N-BF` error codes: `unauthenticated`, `email_not_verified`, `missing_fields`, `blocked` (blocker side only), `duplicate_request`, `rate_limited`, `not_found`, `validation_failed`, `seat_taken`, `stale_state`, `server_error`).

**Platform prerequisites travel with their first use (X-22):** location purpose string + `NSLocationDefaultAccuracyReduced` in K05; Push capability/`aps-environment` in K17; Sign in with Apple entitlement in K18; `ITSAppUsesNonExemptEncryption` and privacy manifest in K20 (archive-only). Fix in K01: remove the global `.preferredColorScheme(.dark)` lock (the design round decides; FIG-V says no light mode exists, so dark is the likely outcome).

### 2.3 Supabase principles, roles, grants, helper functions

1. RLS on every public table (`N-DM` Conventions). Public and private data in separate tables.
2. **Writes.** Clients may INSERT/UPDATE only simple own rows, through **column-level grants** that list exactly the editable columns (X-30). Every state machine changes only through RPCs; those tables grant UPDATE on no status column. Server-owned columns (`id`, `created_at`, `seq`, status fields, `hidden_at`) are never granted.
3. **Every write and every read of other users' content requires a live, eligible caller** (X-05, X-27): restrictive policies call `private.caller_ok()` = caller's profile exists, `account_status = 'active'`, and a `legal_acceptances` row with `age_confirmed` exists. A stale JWT for a deleting or deleted account fails these policies on PostgREST, Storage and Realtime alike. Exception list (own-row reads and the eligibility RPCs) is explicit in 4.2.
4. **Block** via one restrictive policy per user-content table calling `private.is_blocked(me, owner)` (`N-DM`; `R-BE §1.10`).
5. **Helper functions** live in schema `private` (not exposed by PostgREST, `config.toml [api] schemas = ["public"]`). They are `security definer`, `stable`, `set search_path = ''`, owned by `postgres` (the owner of all tables created by migrations, so RLS does not apply inside them; no table uses `FORCE ROW LEVEL SECURITY`), and **return booleans or IDs only**. Grants: `revoke all on schema private from public`; `grant usage on schema private to authenticated`; `grant execute` only on the named helpers used in policies: `is_blocked(a,b)`, `caller_ok()`, `is_participant(conversation_id)`, `can_view_profile(profile_id)`, `can_view_project(project_id)`, `favourites_visible(profile_id)` (C-27, X-17). Participant checks go through `is_participant` to avoid policy recursion on `conversation_participants` (X-17).
6. **RPCs** are `security definer` in `public`, `set search_path = ''`, `revoke execute from public, anon`, `grant execute to authenticated`. Each one: checks `caller_ok()` first, takes locks in the global order (4.5), re-validates state, writes, enqueues outbox rows, returns a typed result.
7. Business invariants are also CHECKs, partial unique indexes and constraint triggers (`R-BE §1.1` item 7).
8. pgTAP proves: policies evaluate correctly as `authenticated`; helpers are callable; `recommend` sees private settings while callers cannot; blocked pairs in both directions on every read path.

### 2.4 RPC inventory (complete for v0) and idempotency

Every retryable mutation takes a client `op_id uuid`; the server stores `(caller, op_id) → result` in `private.op_results` for 24 h and replays the stored result on retry (X-09). Messages use `client_id` the same way.

| RPC | Slice | Purpose | Key checks / idempotency |
|---|---|---|---|
| `accept_terms(terms_version, privacy_version, age_confirmed)` | K04 | 18+ + Terms; server timestamp | `age_confirmed` true; repeat is a no-op |
| `decline_eligibility()` | K04 | Under-18 path | Sets `deleting`; client then calls `delete-account` |
| `handle_available(text)` / `set_handle(text)` | K05 | Handle 3–20 (AD) | Reserved/blocked terms; 30/min (`N-BF`) |
| `save_onboarding_step(step, payload)` | K05 | Save after each step | Per-step validation; last-write-wins per step |
| `complete_onboarding()` | K05 (draft creation from K06) | Browse-ready check, sets `onboarding_completed_at`; Start users get exactly one onboarding draft (unique `projects (owner_id) where origin = 'onboarding'`) | Idempotent |
| `missing_fields(action)` | K05 | Returns fields missing for `send_request`/`join`/`publish` (4.8) | Read-only |
| `save_project_draft(...)` | K06 | Create/update draft | Owner; draft only |
| `publish_project(id, op_id)` / `close_project(id, op_id)` / `complete_project(id, op_id)` / `renew_project(id, op_id)` / `delete_draft(id)` | K06 | Project machine (4.6) | Project lock; replay-safe |
| `update_published_project(id, fields)` | K06 | Edit title, description, cover, timing while published | Locked fields per 4.6 |
| `add_project_role(id, role_id)` / `remove_project_role(role_row_id)` | K06 | Seats | Remove only open seats; expires their pending requests |
| `recommend(surface, limit)` | K07 | Ranked IDs + band + reason codes | 2.10 |
| `record_feedback(target_type, target_id, kind)` / `clear_feedback(...)` | K07 | like/save/hide/not_my_style | PK makes it idempotent |
| `send_request(kind, recipient_id, project_id, project_role_id, time_commitment, message, op_id)` | K08a | Join / collaborate / invite | 4.4, 4.8; replay returns same request |
| `respond_request(id, accept, decline_reason, op_id)` | K08a | Accept/decline | 4.5; replay of the same outcome returns success |
| `withdraw_request(id, op_id)` | K08a | Sender withdraws | Same |
| `mark_read(conversation_id, up_to_seq)` | K08b | Unread state | Monotonic |
| `set_muted(conversation_id, muted)` | K08b | Mute pushes | Own row |
| `block_user(id)` / `unblock_user(id)` | K09 | Block both ways | 2.11 |
| `submit_report(subject_type, subject_id, category, context, op_id)` | K09 | Report | 2.11; 10/day |
| `submit_taste(selections, answers, op_id)` | K13 | Replace onboarding taste evidence, recompute | Replace semantics; zero selections allowed (skip) |
| `set_favourite(...)` / `remove_favourite(id)` | K14 | Favourites | Unique per (profile, source, external_id) |
| `register_device_token(token, environment)` / `unregister_device_token(token)` | K17 | Push tokens | 2.9 |
| `begin_account_deletion()` | K04 (minimal) / K16 | Enter `deleting` state | Idempotent |

### 2.5 Edge Functions and scheduled jobs

| Function | Auth | Contract |
|---|---|---|
| `delete-account` | Either the user's own JWT (refused unless `account_status in ('active','deleting')`), or the server secret header `x-kizuki-job-secret` with `{profile_id}` for the `resume-deletions` job and abandoned sign-ups; the secret path only accepts profiles already in `deleting` or never eligible | 4.7. Idempotent and resumable; each step records progress in `private.deletion_jobs`. K04 ships the auth-only version; K16 adds storage, Apple revoke and retention marks |
| `send-push` | **`verify_jwt = false` + required header `x-kizuki-push-secret`**, constant-time compared to a function secret; any request with a user JWT and no secret is rejected (X-06, C-02) | Body is `{outbox_id}` or `{drain: true}` only; recipient, text and route are loaded from the outbox row with the service role; 2.9 |
| `tmdb-proxy` | User JWT + `caller_ok` via RPC check | GET search/details; per-user throttle; returns id, title, year, poster path; short in-memory cache (`R-IOS §6.1`) |

Not in v0 (from `N-BF`): `recommendations` Edge Function (D15 puts scoring in SQL), `validate-link`/`recheck-links`, `track`, `export-account` (launch blocker), Made Together functions.

**pg_cron jobs.** `expire-projects` hourly; `expire-requests` daily (`N-BF`); `drain-outbox` every minute (2.9); `erase-deleted-message-text` daily (4.7, D42); `purge-abandoned-signups` daily (accounts with no `legal_acceptances` after 7 days [design], X-27); `resume-deletions` hourly (4.7). Jobs that call `send-push` or `delete-account` use `pg_net` with the URL and secret read from **Supabase Vault** at run time; migrations reference only the Vault secret *names*, never values or URLs (C-03). Reads also filter `expires_at > now()` so a missed job cannot show stale items.

### 2.6 Realtime chat

**Plain language.** One chat per accepted pair at a time. A block closes it and hides it from both people. If they later unblock and a new request is accepted, a fresh chat starts. Messages arrive live, and the app re-reads anything it might have missed.

- **Conversation generations (X-11, C-06).** `conversations` has a partial unique index on `(pair_low, pair_high) where closed_at is null`: at most one *open* conversation per pair. Accept reuses the open one or creates a new generation. `block_user` sets `closed_at` and `closed_reason = 'blocked'`. While a block exists, the restrictive block policy hides that pair's conversations and messages from both sides (consistent with "vanishes everywhere"). After unblock, a blocked-closed conversation stays hidden [design: no unexpected resurfacing of old history]; a new accepted request creates a new conversation.
- **Transport.** Postgres Changes on `public.messages` filtered `conversation_id=eq.<id>`; RLS re-checked per event, so a block or moderation hide applies immediately (`R-BE §3.1–3.3`). Free plan limits (200 connections, 100 msg/s) are far above v0 (`R-BE §3.2`).
- **Ordering and reconciliation (X-16).** `messages.seq bigint generated always as identity` and `created_at default now()` are server-owned (no INSERT grant on either). Pages use the cursor `(created_at, id)`. On subscribe, reconnect and foreground: fetch `created_at > last_seen_created_at - interval '5 minutes'` and merge by `id` (dedupe). The 5-minute overlap covers transactions that took their timestamp early and committed late; while subscribed, late commits arrive as Realtime events anyway because changes are emitted at commit. Subscribe first, then fetch, then merge (no gap between the two).
- **Send.** PostgREST insert of `(conversation_id, client_id, body)` only; unique `(sender_id, client_id)` makes retries safe. A `before insert` trigger: locks the conversation row `FOR SHARE`, re-checks `closed_at is null`, caller is a participant, caller and other participant are active and not blocked, message not over rate limit (30/min [design]); sets `sender_id = auth.uid()`. Because `block_user` updates the conversation row `FOR UPDATE`, a send racing a block either commits before the block or sees the closed row and fails (X-02).
- **Unread.** `conversation_participants.last_read_seq` via `mark_read`; unread dot only, no counts [design].
- **Scope (accepted OD-2, OD-10).** Direct chats only; text 1–2000 chars; no edit, no unsend, no attachments. Project context pinned in the header (Product Requirements "Messaging requirements").
- **Swap seam.** `ChatTransport` protocol in Core; Broadcast-from-DB later without a schema change (`R-BE §3.2`).
- SDK facts (verified in source by `R-BE §3.4`): register `postgresChange(InsertAction.self, …)` before `subscribeWithError()`; share one client so refreshed tokens reach Realtime; `removeChannel` on teardown (2.2 `SessionScope`).

### 2.7 Storage

| Bucket | Visibility | Path | Writer | Limit |
|---|---|---|---|---|
| `avatars` | public, not listable | `<uid>/<uuid>.jpg` | owner | 1 MB |
| `user-media` | private, signed URLs | collab photos `<uid>/collab/<photo_id>/{thumb,full}.jpg`; project covers `<uid>/project/<project_id>/<uuid>.jpg` | owner | 2 MB |
| `taste-cards` | public read-only | `<realm>/<slug>.jpg` | seed only | 1 MB |

- One private bucket instead of v1's two (C-18). Client makes renditions, converts HEIC, strips EXIF/GPS (`R-BE §5.3`). Avatars max 1024 px (`N-ARCH`).
- **Policies.** INSERT: first folder = caller id **and** `private.caller_ok()` (a deleting account cannot upload, X-05). SELECT on `user-media`: owner, or a visible `collab_photos`/`projects` row references the path and the block/hidden checks pass. DELETE: owner. No UPDATE (no upsert).
- **Path integrity (C-37).** CHECK constraints: `profiles.avatar_path like id::text || '/%'`, `projects.cover_path like owner_id::text || '/project/' || id::text || '/%'`, `collab_photos.storage_path_prefix like owner_id::text || '/collab/%'`.
- **Revocation window, stated (X-04).** Signed URLs stay valid until expiry (Supabase Storage downloads docs, cited by X-04). v0 signs with **10-minute TTL** [design]; a block or hide stops *new* URLs immediately and old ones within 10 minutes. **Public avatars are an accepted exception**: anyone with the URL can fetch the image; object names are random UUIDs and a new name is used on change.
- **Caching.** Image cache is scoped to the signed-in user (`SessionScope`), keyed by object path, purged on sign-out/account switch, and entries for a user are evicted when the app learns of a block (block action or a 404/403 on refresh). Signed URLs are cached only until 1 minute before expiry.
- Tests (K10): pgTAP policy matrix incl. blocked and hidden; live suite: URL minted before block still works until TTL (documented behaviour), new signing denied after block; deleting account cannot upload.

### 2.8 Auth, eligibility, recovery

**Plain language.** You sign up with email and password (Apple once the developer account exists). You confirm your email with a 6-digit code, then confirm you are 18 or older before anything else is saved. Forgot your password? You get a 6-digit code, not a link. Nobody under 18 gets further than that screen, and their account is removed.

- **Order (X-27).** Sign-up → verify code → **Terms + 18+ screen first** → handle and name → onboarding. Before `accept_terms`, the only data stored is the auth identity and the empty provisioned rows (repo `provision_profile` copies nothing). `private.caller_ok()` requires an eligibility row, so a client that skips the screen can read nothing of other users and write nothing except `accept_terms`/`decline_eligibility`.
- **Under 18.** `decline_eligibility()` → `deleting` → client calls `delete-account` (auth-only version ships in K04 with the gate, C-24). If the client never calls it, `purge-abandoned-signups` deletes accounts with no eligibility row after 7 days via the job-secret path.
- **Email/password (D30).** `signUp` with 10+ chars (repo `config.toml` already sets minimum length 10, per X audit). Verify with 6-digit code (accepted OD-3): confirm-signup template contains `{{ .Token }}`; `verifyOTP(type: .signup)`. Leaked-password protection depends on the staging plan (OD-16) **[unverified plan availability]**.
- **Password recovery by code (X-26, C-28).** `resetPasswordForEmail(email)`; recovery template with `{{ .Token }}`; `verifyOTP(type: .recovery)` returns a recovery session; `SupabaseBackend` maps `passwordRecovery` to root phase `passwordRecovery`, which shows only "Set a new password" → `updateUser(password:)` → `main`. Expired or wrong code: typed error, resend after 60 s (Supabase default per `R-BE §4.2`). No deep links or redirect URLs needed. The live suite (8.4) tests request → code from Mailpit → new password → old password rejected.
- **Email sending.** Built-in mailer: 2 emails/hour/project (`R-BE §4.2`) → custom SMTP needed before any staging sign-up beyond the seeded accounts (OD-15 pending).
- **Sign in with Apple (D13; K18).** Native nonce flow, `signInWithIdToken(.apple)` (`R-BE §4.1`). Blocked for device verification by D39 (App ID capability).
- **Never merge silently (X-14).** Supabase links identities with the same verified email automatically (Supabase identity-linking docs, cited by X-14). Contract: (1) K18 starts with an auth spike that reproduces the collision (Apple real email = existing email account) on local and staging; (2) if linking happens, the app detects it (`user.identities` gained `apple` during this sign-in and the account already had `email`), shows "We connected your Apple ID to your existing Kizuki account" with **Undo** (`unlinkIdentity`), and records the event; (3) if the spike shows a supported way to require confirmation first, use it instead. Partly resolved; OD-17.
- **Session.** PKCE + Keychain per environment (repo). Sign-out = `unregister_device_token` → `signOut(scope: .local)` → cancel `SessionScope` → purge caches (X-07).
- **Account linking, demo account.** App Review demo account is a seeded password user on staging (D30 rationale).

### 2.9 Push (APNs)

D35: real push for new request, acceptance, new message.

- **Trust boundary (X-06, C-02).** `send-push` has `verify_jwt = false` and requires `x-kizuki-push-secret`; requests without it, or with only a user JWT, get 401. The body is `{outbox_id}` (fast path) or `{drain: true}` (cron). Recipient, text and route are read from `notification_outbox` with the service role; no caller-supplied recipient or text is ever used. Deno tests: user-JWT call rejected; forged body fields ignored.
- **Environment safety (C-03).** No Database Webhook is created by migrations. The fast path is an `after insert` trigger calling `net.http_post` with URL and secret read from Vault secrets `push_function_url` and `push_function_secret`; each environment sets its own Vault values through the ref-guarded remote script (3) or the local setup script. If either secret is missing, the trigger does nothing and the cron drain still delivers once configured. CI check: migrations must not contain `functions/v1`, `supabase.co`, `sb_secret_`, or JWT-shaped strings.
- **Durable delivery (X-08).** Outbox columns: `status (pending, sending, sent, failed, dead)`, `attempts`, `next_attempt_at`, `lease_until`, `dedupe_key unique` (e.g. `message:<id>:<recipient>`). Claim: `update … set status='sending', lease_until=now()+'2 min', attempts=attempts+1 where id in (select id … where status in ('pending','failed') and next_attempt_at <= now() or (status='sending' and lease_until < now()) for update skip locked limit 50) returning *`. Success → `sent`. APNs 429/5xx/timeouts → `failed` with backoff 1 m, 5 m, 30 m, 2 h; after 5 attempts → `dead`. 410/`BadDeviceToken` → delete token, mark `sent` (nothing to deliver). `apns-collapse-id` = outbox id so a rare double send collapses on device. `drain-outbox` cron runs every minute.
- **Token ownership (X-07, C-10).** `device_tokens` primary key is `token`; columns `profile_id`, `environment`, `updated_at`. `register_device_token` upserts and **reassigns** the token to the caller (removing it from any previous account). `unregister_device_token` runs before sign-out; account switch calls it for the old session first. Environment comes from the build configuration (Debug → `sandbox`; Staging/Release → `production`) and the RPC accepts only those two values; `send-push` uses the matching APNs host.
- **Eligibility at delivery (X-07).** Before sending, `send-push` re-checks: recipient active, not deleting; actor and recipient not blocked; `notify_requests`/`notify_messages` on; conversation not muted; for request kinds, the request still exists and is not hidden. If any fails → mark `sent` with `skipped_reason`.
- **Payload.** No message body on the lock screen [design]: "New message from @handle". Foreground suppression is client-side: `userNotificationCenter(_:willPresent:)` returns no banner when that conversation is on screen (C-31).
- **Prerequisites.** APNs `.p8` key, Team ID, Key ID in function secrets; Push capability (K17). Both need the Apple account (D39), so until then the pipeline is verified with pgTAP (outbox rows per event), Deno tests with a mocked APNs endpoint, and the drain job on the local stack.

### 2.10 Matching: SQL `recommend`, privacy-safe reasons, cold start

**Plain language.** For every candidate, the database asks "does this fit me?" and "would they want me?", combines both, and hides anything blocked, incompatible on pay or location, expired or already requested. People who skipped the taste cards still get a feed: taste counts as "neutral" for them. Reasons never reveal someone's private availability, work mode, pay preference or project interests.

**Decision.** SQL function per D15; Notion v1 formula per accepted OD-1; pgvector, Edge Function scorer, serendipity mix, MMR, jitter, exposure floor, complementarity bonus and set logging are not in v0 (2.10 "Cut" below; changelog C-18).

**Contract** (stable; replaceable behind `private.app_config.recommender`):

```
recommend(surface text /* home_projects | home_people | onboarding_preview */, p_limit int)
returns table(target_type text, target_id uuid, rank int, band text /* close|adjacent|stretch|null */,
              reasons jsonb /* [{code, params}] */, rules_version text)
```

`security definer`, owned by `postgres` (reads private settings and taste as table owner; 2.3), checks `caller_ok()`, re-applies `is_blocked` and hidden/active checks explicitly, returns IDs + band + reason codes only. Cards then load through normal RLS selects. Limits: 10 / 8 / 5 [design].

**Stage 0 — eligibility** (`N-RS`, `N-ONB`, D3, accepted OD-12):
- Not self; no block either way; not hidden-by-viewer (`recommendation_feedback` hide/not_my_style); viewer has not reported the target.
- Person: eligible, onboarded, active, not `hidden_at`, `discoverable = true` (`discoverable` is used **only** here, C-08), ≥1 role.
- Project: `published`, `expires_at > now()`, not hidden, ≥1 open seat, owner passes the person rules.
- No pending or accepted request between viewer and target (for projects: for that project).
- Compensation: viewer preference `paid` → project `compensation_status in (paid, either)`. People: hide a paid-seeking candidate only when every published project of the viewer is `unpaid` (accepted OD-12).
- Work mode: remote ↔ remote/either; local ↔ same `city_id` and local/either; either ↔ both. Fewer than 3 local results → add remote-compatible with reason `remote_fallback` (`N-ONB` C4).

**Stage 2 — components** (each in [0,1], null-safe; weights in `private.ranking_weights`, `N-ALG`):

| Component | Weight | v0 definition |
|---|---|---|
| Role R | 0.30 | Project candidate: 1.0 viewer's primary role = an open seat's role; 0.8 a secondary role does; 0.4 same realm, no role match **[design deviation: Notion says "adjacent role in the taxonomy"; no adjacency table exists yet, C-38]**; else 0. Person candidate: 1.0 different primary roles (complementary), 0.5 same role. |
| Taste T | 0.25 | `0.6·facet + 0.4·favourites`. **facet**: cosine `c` of the two strength·confidence vectors; if the primary realms differ, only shared-family facets are compared (bridge, `N-ALG`); mapped `m = (c+1)/2`; shrunk `0.5 + (m − 0.5)·avg_confidence`; if either vector has zero norm → 0.5. **favourites**: rarity-weighted overlap (`N-ALG` Part 1b) over the eligible population (2.13); if either side has no favourites or any denominator is 0 → 0.5. **Cold start**: viewer mean confidence < 0.3 → T weight 0.10, R and L +0.075 each (`N-ALG`). |
| Logistics L | 0.20 | Mean of work mode (1.0 compatible, +0.1 same city, cap 1), availability (same 1.0, neighbour 0.7, varies 0.8, two apart 0.4, unknown 0.7), timeframe (overlap 1.0, unknown or flexible 0.7) (`N-ALG`). |
| Intent I | 0.15 | start→join 1.0, start→start 0.6, any explore 0.5; +0.2 if project type ∈ viewer's preferred types, cap 1 (`N-ALG`). |
| Trust & freshness F | 0.10 | Mean of verified email (1.0 / 0.6) and freshness `exp(−days/30)` from `profile_settings.last_active_on` (people) or `exp(−age/21)` (projects). `last_active_on` is private, day precision, written by `private.touch_activity()` from RPCs and the message trigger (C-30). |

`D(a→b)` per side (for a project candidate, `b→a` is the owner's view of the viewer: owner taste, project seats vs viewer roles, project logistics vs viewer, owner intent). `score = 2·D(a→b)·D(b→a)/(D(a→b)+D(b→a))`; if both are 0, score 0. Show only `score ≥ 0.35` (`N-ALG`, `N-RS`). Max 2 items per owner (`N-RS`). Tie-break `(score desc, published_at desc, id)`.

**Stage 3 — bands without a mix.** Band is computed only when **both** sides have taste evidence: close c ≥ 0.6; adjacent 0.3 ≤ c < 0.6; stretch c < 0.3. Adjacent and stretch require a common thread (shared favourite; shared shared-family facet with both strengths > 0.3; same city; same project type; complementary role on a live project), and stretch also requires R ≥ 0.8 and L ≥ 0.6 (`N-ALG` Part 0, X-20). **Cold start (C-12):** if either side has no taste evidence, band is `null` and the item is admitted by Stage 0 + threshold alone. Home therefore always shows the logistics/role-compatible set even for a user who skipped every taste step.

**Reasons: privacy rule (C-01, D41).** A reason may disclose only (a) the viewer's own data, (b) the candidate's public fields (roles, realm, public city, the project's own public fields), (c) a taste-family overlap name as `N-ALG` specifies, (d) a shared favourite only if the candidate's `show_favourites` is on. It may never disclose a person's availability, work mode, compensation preference, preferred project types or intent.

| Code | Shown as (copy is design-round) | Applies to | Condition |
|---|---|---|---|
| `needs_your_role` | Needs your role | projects | R = 1.0 |
| `complementary_role` | Your roles fit together | people | different primary roles |
| `similar_taste` `{family}` | Similar sense of {family} | both | shared facet, both strength·confidence > 0.3; gated by `app_config.show_taste_reasons` until real facets exist (risk 7) |
| `shared_favourite` `{title}` | You both listed {title} | both | candidate `show_favourites` on, both consent to matching |
| `same_project_type` | Open to the same kind of project | projects | project type ∈ viewer's preferred types |
| `same_window` | Fits your available time | projects | project `time_commitment` compatible with viewer band |
| `same_city` `{city}` | Both in {city} | both | same public city, local/either compatible |
| `works_remotely` | Remote-friendly | projects | project remote/either and viewer remote-compatible |
| `remote_fallback` | Nothing nearby yet, so here is a remote one | both | Stage 0 fallback |
| `stretch_pick` | A stretch pick | both | band stretch; always with one thread reason |

pgTAP proves no person-candidate result carries `same_window`, `works_remotely` or `same_project_type`, and that no output field contains a private value.

**Golden fixtures (pgTAP, K07/K13).** Zero-taste viewer; zero-taste candidate; cross-realm pair (bridge only); all-common favourites (rarity 0 → 0.5); paid seeker vs unpaid project (excluded); blocked pair both directions (excluded); hidden project; expired project; local with < 3 results (fallback); owner with 3 projects (max 2); equal scores (tie-break).

**Cut from v0 (not locked; C-18):** serendipity mix and the O8 screen (preference stored as default `mix_it_up`), MMR, ±0.03 jitter, exposure floor, complementarity bonus, `recommendation_sets/items` logging, weekly re-fit, weak ties, set caching. The contract does not change when they return.

### 2.11 Safety: report, block, moderation states

- **Report (X-03, C-35).** `submit_report` is `security invoker`: it reads the subject **as the caller** through RLS (if the caller cannot see it → `not_found`), builds the snapshot from that projection only, then calls the narrow definer `private.file_report(...)`. Storage: `reports(id, reporter_id, subject_type, subject_id, category, status, created_at)` readable by the reporter; `private.report_evidence(report_id, subject_owner_id, snapshot, reviewer_note, reviewed_at)` service-role only. For profiles, projects and collab photos the RPC also writes the reporter's `hide` feedback so the item stays hidden for them across relaunches. Categories as v1 (union of `R-BE §1.2` and `R-IOS §4.2`). 10/day (`N-BF`).
- **Moderation state per subject (X-10, C-11).**

| Subject | State column | Effect when set |
|---|---|---|
| profile | `profiles.hidden_at` (auto/reviewer); `account_status = 'suspended'` (reviewer only) | hidden: out of discovery, Search and profile pages; existing chats continue. suspended: `caller_ok()` fails (no reads of others, no writes), all content hidden |
| project | `projects.hidden_at` | invisible to non-owners; pending requests cannot be accepted (4.5) |
| collab photo | `collab_photos.hidden_at` | out of grid/profile; no new signed URLs |
| link/embed | `portfolio_sources.hidden_at` | not shown on profile |
| message | `messages.hidden_at` | non-senders see a "message hidden" placeholder; RLS hides the body, so Realtime events carry nothing |
| request | `requests.hidden_at` | hidden from the recipient; cannot be accepted; expires normally |

- **Auto-hide (D34, accepted OD-6).** A `security definer` trigger on report insert counts distinct **qualifying** reporters on the same subject: eligible, verified email, account ≥ 3 days old [design, anti-brigading], not the subject owner. At 3 it sets the subject's state column and marks reports `reviewing`. Never auto-suspends or bans (`N-TS`). Reviewer acts daily in the dashboard (D16, D34): `actioned` (keep hidden / suspend / delete) or `dismissed` (clear `hidden_at`).
- **Block side effects** (`block_user`, pair lock 4.5): insert block; withdraw pending requests both ways; close the pair's open conversation; remove `project_members` between them in both directions and reopen those seats on published projects (C-36); delete likes/saves between them; queued pushes between them are skipped at delivery. `unblock_user` only deletes the row.
- **Blocked side learns nothing (C-07).** Every RPC returns `not_found` to the blocked party (same as a missing target); `blocked` is returned only to the blocker. The closed conversation is hidden from both (2.6), so there is no "closed" banner.
- **Image safety (accepted OD-11).** Report + auto-hide + daily review; no hold-for-review. Text filter trigger on handles, names, bios, project text, captions, request and chat messages (`private.blocked_terms`).
- **Apple 1.2 coverage (C-21).** Terms of Use + Community Guidelines with a zero-tolerance clause (and YouTube ToS reference) are linked from the Terms/18+ screen (K04) and Settings (K15); support contact in Settings (OD-15); report on every UGC surface is a done-criterion for each slice that adds a surface; App Store age rating 18+ in K20 (AD).

### 2.12 Embeds (profile widgets)

Unchanged from v1 except moderation: YouTube, SoundCloud, Bandcamp players; Instagram, Letterboxd, others link-out (D23, AD). `portfolio_sources` (`N-DM`) with relation, two consents default off (`N-ONB` C3), `hidden_at`. Allow-list in the pure client parser and a DB trigger; `https` only. Facade first, no third-party request until tap; `WKWebView` non-persistent, locked to the player host, outbound links to `SFSafariViewController` (`R-IOS §5.1`). YouTube Referer `https://club.kizuki.ios` (one bundle ID, D43; `R-IOS §5.3`). Bandcamp only via its own embed `src` **[unverified path shape]**. Each embed has Report. No server-side link checks in v0. Provider smoke test (8.4) uses real, public, owner-authorised URLs on a device, not the seed's example URLs (X-28).

### 2.13 Taste cards and favourites

- **Taste cards (D21).** O4: 12 cards, pick 3–5, **skippable** (zero allowed). O5–O7: 3 fixed pairwise choices, skippable; no adaptive follow-ups in v0 (C-18). Placeholder art with `license_ref = 'placeholder'`; ≥ 24 per realm; release pgTAP gate forbids placeholders in a release dataset (`R-BE §1.4`). Provisional facet set ≈ 30 values in 6 families until ticket 007.
- **Derived, replay-safe taste (X-09).** `taste_facets` is a cache recomputed by `private.recompute_taste(profile_id)` from source rows: card selections and the shown set (`taste_seed_shown`), pairwise answers, feedback rows (save +0.3, more +0.5, less −0.5, not my style −0.6, hide −0.2), accepted requests (+0.8), using `N-ALG` update rules. `submit_taste` **replaces** the caller's onboarding evidence, then recomputes; retries cannot double-count. RPCs that change sources set `profile_settings.taste_dirty_at`; `recommend` recomputes dirty viewers first. Requests (K08a) only set the flag; K13 brings the recompute, so there is no forward dependency (X-23).
- **Favourites (D22).** Films via `tmdb-proxy`, music direct from device to MusicBrainz (1.1 s queue, 600 ms debounce, contact `User-Agent`) (`R-IOS §6.2`). `favourites(profile_id, source, kind, external_id, title, year, position, refreshed_at)`, ≤ 5 per kind, text-only music tiles, TMDB posters hotlinked, refresh within 6 months (TMDB terms).
- **Two consents, as for links (X-18, C-09).** `profiles.show_favourites` (public flag, default off) controls display; `profile_settings.favourites_for_matching` (private) controls use in ranking, shown as an explicit toggle on the picker, default on (OD-18). Rarity population = active, eligible, onboarded profiles with matching consent on; turning consent off removes the user from overlap and rarity on the next `recommend` call (computed at query time).

---

## 3. Environments and config guardrails

### Plain language

Four places the app can run: your laptop, the CI robot, staging (fake data, used by TestFlight) and production (real, empty, untouched in v0). The app, the build check and every script that touches a remote project know the exact staging address and refuse anything else. Production is refused outright in v0, and seed data can only reach a database that carries a "staging" marker.

### Detail

| Env | Backend | App build | Data | Status |
|---|---|---|---|---|
| **Local** | `supabase start` at `http://127.0.0.1:54321` (CLI `supabase@2.122.0`) | Debug, `club.kizuki.ios.local` | `supabase/seed.sql` (generated) + local storage uploader; Mailpit | Docker runtime pending (ticket 005, accepted OD-9). Native runtime runs pgTAP today but uses random ports (`R-BE §7.3`) |
| **CI** | `backend` job on `ubuntu-latest` (Docker): Postgres, Auth, REST, Realtime, Storage, Edge runtime | `ios` job on `macos-15`: fixture UI tests + contract replay tests | Same seed | `local-backend` exists; extended in K02 (8.4) |
| **Staging** | `https://ankgfqkgflcalmlreetu.supabase.co` (D38) | Staging config, bundle `club.kizuki.ios` (D43) | Fictional `@seed.kizuki.test` users loaded by the staging loader | Exists. **Not yet buildable**: `Staging.xcconfig` has empty `SUPABASE_URL` and the publishable key is not supplied (D38); the pre-build validator rejects both until set (C-22, X-21). TestFlight needs Apple enrolment (D39) |
| **Production** | `enosggckdxjiaqtxalhg` | Release | None | Refused by every v0 tool (below) |

**Staging pinning (X-21, C-15).**
1. `AppConfiguration`: `.staging` requires `host == "ankgfqkgflcalmlreetu.supabase.co"` exactly (a constant `approvedStagingHosts = ["ankgfqkgflcalmlreetu.supabase.co"]`), not "any non-production `*.supabase.co`" (repo `AppConfiguration.swift:41–44`).
2. `scripts/validate-release-config.py`: same exact allowlist for Staging; **Production configuration fails unconditionally in v0** with "Production builds are disabled until the release ticket" (two independent checks with 1). Tests extend `test-release-config.py`, including the reviewer's probe `unapproved-review-probe.supabase.co` (must fail).
3. `Staging.xcconfig`: `KIZUKI_BUNDLE_ID = club.kizuki.ios` (D43), `SUPABASE_URL = https:/$()/ankgfqkgflcalmlreetu.supabase.co`; key in git-ignored `Staging.private.xcconfig`.
4. **One remote gateway.** Every remote CLI action goes through `scripts/remote/kz-remote.sh <command>`: it hard-codes `PROJECT_REF=ankgfqkgflcalmlreetu`, refuses `--project-ref`, `--db-url` and `link` overrides, refuses if `supabase/.temp/project-ref` (link state) names any other ref, and wraps `db push` (never `--include-seed`), `functions deploy`, `secrets set`, Vault secret setup and auth configuration. CI fails if any other script contains `db push`, `functions deploy`, `secrets set`, `link` or `--db-url` (extends the existing `supabase-local.sh` rule, `R-BE §6.4`).
5. **Effective-destination check.** Before any write, the gateway and the staging loader resolve the actual destination: API host from the URL they will call, and for SQL a query `select value from private.environment_marker` that must return `staging`. The marker row is inserted once by a staging-only bootstrap command in the gateway, never by a migration. Production lacks the marker, so an empty production database still refuses seeds (X-21: "empty or all fictional emails" alone is not a safeguard).

**Seeding staging, guard-compatible (C-14).**
- One generator `scripts/seed/generate.py` (seeded RNG, `uuid5` IDs) emits `seed/data.json` + image manifest. Two loaders read it: `seed/load_local.py` (writes `supabase/seed.sql`, uploads images via the existing loopback guard `require_local_url`) and `seed/load_staging.py` (runs only inside `kz-remote.sh`; creates users through the Admin API with `email_confirm = true` and fictional passwords; inserts rows over the pooled connection after the marker check; uploads images through the Storage API; every email must end `@seed.kizuki.test` and every target host must equal the staging host).
- Guardrail wording: **migrations** may reach staging and (later) production; **seed data** may reach local and staging only, and only through these loaders. Taxonomy rows (roles, project types, cities, facets, blocked terms) are migrations; people/projects/photos are seed (`R-BE §6.4`).

**Staging auth and secrets configuration (C-16).** `kz-remote.sh auth-config` applies the auth settings that local `config.toml` holds (email templates with `{{ .Token }}` for signup and recovery, confirmations on, minimum password 10, SMTP once OD-15 lands, JWT expiry). Whether CLI 2.122.0 can push these to a hosted project is **[unverified]**; fallback is a dashboard checklist in the same script's README, checked at the K19 smoke test. Plan choice (Free pauses inactive projects; leaked-password protection and PITR depend on plan **[unverified details]**) is OD-16.

**Other guardrails kept from v1.** `AppConfiguration` rejects service-role/secret keys; Keychain session key per environment+URL; Edge Function secrets only in function secrets/Vault; `KizukiTestSupport` compiled empty in Release (2.2); CI grep forbids inserts into user tables, function URLs and secrets in migrations.

**Local caveat.** OrbStack/Colima (accepted OD-9) keeps port 54321 and the existing guards. Until ticket 005 closes, developers use the native runtime for SQL work and rely on CI for live suites; no app change is made to accept random ports.

---

## 4. Data model and contracts

### 4.0 Plain language

About 35 tables in five groups: who you are, what you make, how you connect, staying safe, and system plumbing. Private things (availability, work mode, pay preference, onboarding answers, taste scores, activity) sit in tables only you can read; your city is public (D41). Requests, projects and accounts move through fixed states that only the database changes, in a fixed lock order so two people acting at once cannot break them.

### 4.1 Enums

As v1 (Notion names, `N-DM`) with these changes: `account_status` = active, deleting, suspended (C-33: no `deactivated`); new `project_origin` = onboarding, manual; `outbox_status` = pending, sending, sent, failed, dead; `project_status` = draft, published, closed, past and `project_closed_reason` = filled, owner_closed, expired, completed (AD); `request_kind` = join_project, collab_person, invite_to_project (D36); `request_status` = pending, accepted, declined, withdrawn, expired; `feedback_kind` = like, save, more_like_this, less_like_this, not_my_style, hide (D25). Others unchanged: realm (film_video, music_sound, visual_arts, mixed_practice), intent, serendipity, availability_band, work_mode, compensation_preference, compensation_status, pairwise_choice, source_relation, link_status, report_status.

### 4.2 Tables, key columns, RLS

`me` = `(select auth.uid())`. Every policy on other users' rows also passes `caller_ok()` and the block policy (2.3). "Own-row exception" = readable without `caller_ok()` so the eligibility and deletion screens work.

**Identity and profile**

| Table | Key columns | RLS (select / write) |
|---|---|---|
| `profiles` | id, handle (3–20), display_handle, display_name, bio ≤280, avatar_path (CHECK prefix), primary_realm, secondary_realms, **city_id, country_code, city_unlisted (public, D41)**, show_favourites, discoverable, account_status, deleting_since, hidden_at, onboarding_completed_at | Own row always (own-row exception). Others via `can_view_profile`: eligible + onboarded + active + not hidden; **or** shares a request, conversation or project with the viewer (so counterparts keep names when the other is hidden from discovery, C-08). Column-level UPDATE: display_name, bio, avatar_path, secondary_realms, city_id, country_code, city_unlisted, show_favourites, discoverable |
| `profile_settings` | profile_id, primary_intent, serendipity (default mix_it_up), availability_band, work_mode, compensation_preference, preferred_project_type_ids, discovery_focus, onboarding_state, favourites_for_matching, notify_requests, notify_messages, last_active_on, taste_dirty_at | Owner only (own-row exception). Column UPDATE on notify_requests, notify_messages, favourites_for_matching only; onboarding fields via `save_onboarding_step`; last_active_on and taste_dirty_at server-only |
| `legal_acceptances` | id, profile_id, terms_version, privacy_version, age_confirmed, accepted_at | Owner select; insert via `accept_terms` |
| `roles`, `project_types`, `cities`, `facet_catalog` | taxonomy | Read: `caller_ok()`; write: migrations |
| `profile_roles` | profile_id, role_id, is_primary, position (1–3) | Owner + `can_view_profile` / owner write |
| `favourites` | profile_id, source, kind, external_id, title, year, position, refreshed_at | Owner; others if `favourites_visible(profile_id)` (reads `profiles.show_favourites`, public) / RPC write |
| `portfolio_sources` | id, profile_id, source_type, canonical_url, embed_ref, display_title, source_relation, public_display_consent, recommendation_use_consent, link_status, hidden_at, position | Owner; others if consent + `can_view_profile` + not hidden / owner write (host trigger) |
| `device_tokens` | **token (PK)**, profile_id, environment, updated_at | Owner select / RPC only |

**Taste**: `taste_items`, `taste_item_facets(weight)`, `taste_pairs` (read: `caller_ok()`); `taste_seed_selections`, `taste_seed_shown`, `pairwise_answers` (response_ms nullable, never read; `N-DM`), `taste_facets` (derived cache) — owner select, RPC write.

**Projects and content**

| Table | Key columns | RLS |
|---|---|---|
| `projects` | id, owner_id, origin, status, closed_reason, realm, project_type_id, project_type_other ≤40, title, description, compensation_status, work_mode, city_id, country_code, time_commitment, starts_on, ends_on, **flexible_timing** (X-19), expires_at, published_at, cover_path (CHECK prefix), hidden_at | Owner always; others via `can_view_project` (status in published/closed/past, not hidden, owner visible) or membership / insert via `save_project_draft`; edits via RPCs (4.6) |
| `project_roles` | id, project_id, role_id, status (open/filled), filled_by; unique (id, project_id) for the composite FK from requests | Follows project / RPC |
| `project_members` | project_id, profile_id, project_role_id; unique (project_role_id); unique (project_id, profile_id) | Follows project / RPC |
| `collab_photos` | id, owner_id, storage_path_prefix (CHECK), caption ≤140, alt_text, realm, role_id, tags, project_id, hidden_at, created_at | Visible + not hidden; owner always / owner insert/delete (≤24, trigger) |
| `recommendation_feedback` | profile_id, target_type, target_id, kind; PK all four | Owner only; likes private (accepted OD-8) |

**Requests and chat**

| Table | Key columns | RLS |
|---|---|---|
| `requests` | id, kind, sender_id, recipient_id, pair_low, pair_high, project_id, project_role_id (composite FK `(project_role_id, project_id)`), time_commitment, message ≤500, status, conversation_id, hidden_at, expires_at (+14 d), created_at, resolved_at | Sender or recipient (recipient: not hidden) / RPC only |
| `request_decline_reasons` | request_id, reason | Recipient only |
| `conversations` | id, pair_low, pair_high, origin_project_id, created_at, closed_at, closed_reason; partial unique `(pair_low, pair_high) where closed_at is null` | `is_participant(id)` + block policy / RPC only |
| `conversation_participants` | conversation_id, profile_id, joined_at, last_read_seq, muted | `is_participant(conversation_id)` / `mark_read`, `set_muted` |
| `messages` | id, seq (identity), conversation_id, sender_id, client_id, body (nullable after erasure), sender_deleted_at, erased_at, hidden_at, created_at; unique (sender_id, client_id); CHECK `body is not null or erased_at is not null` | `is_participant` + block; body hidden when `hidden_at` and caller ≠ sender / INSERT grant on (conversation_id, client_id, body) only; trigger 2.6 |
| `notification_outbox` | id, recipient_id, kind, actor_id, subject_id, route, status, attempts, next_attempt_at, lease_until, dedupe_key unique, skipped_reason | Service role only |

**Safety and system**: `blocks` (blocker only; RPC), `reports` (reporter-readable, no notes), `private.report_evidence`, `private.blocked_terms`, `private.ranking_weights`, `private.app_config`, `private.environment_marker`, `private.op_results(caller, op_id, result, created_at)` (24 h), `private.deletion_jobs` (no FK; pseudonymous id, purged 30 days after completion).

**Deferred from `N-DM`**: `taste_vectors`, `references`/`profile_references`, `release_credits`, `consent_events`, `project_references`, Made Together tables, `moderation_actions`, `appeals`, `analytics_events`, `recommendation_sets/items` (C-18), handle hold period.

### 4.3 Foreign-key deletion behaviour (X-12)

Profiles are deleted by `auth.admin.deleteUser` cascade at step 4 of 4.7, after pending requests are terminalized in step 1.

| FK | On delete | Note |
|---|---|---|
| profiles.id → auth.users | cascade | exists |
| profile_settings, legal_acceptances, profile_roles, favourites, portfolio_sources, device_tokens, taste_*, recommendation_feedback, conversation_participants → profiles | cascade | private or own data |
| blocks (both columns) → profiles | cascade | |
| projects.owner_id → profiles | cascade | owned projects deleted (v1 OD-7 part, unchanged by D42) |
| project_roles, project_members.project_id → projects | cascade | |
| project_members.profile_id → profiles | cascade; seat reopened by trigger if project published | |
| requests.sender_id / recipient_id → profiles | set null | shown as "Deleted user"; all pending already withdrawn |
| requests.project_id, project_role_id → projects/project_roles | set null | only terminal requests survive; `pending` with null project is impossible (CHECK `status <> 'pending' or (kind = 'collab_person' or project_id is not null)`) |
| conversations.pair_low / pair_high → profiles | set null | partial unique index ignores closed rows; conversation is closed in step 1 |
| conversations.origin_project_id → projects | set null | |
| messages.sender_id → profiles | set null | `sender_deleted_at` set in step 1 (D42) |
| messages.conversation_id → conversations | cascade | conversations themselves are never deleted in v0 |
| collab_photos.owner_id → profiles | cascade | objects removed in step 3 |
| collab_photos.project_id → projects | set null | |
| reports.reporter_id → profiles | set null | |
| report_evidence.subject_owner_id → profiles | set null | plus `subject_owner_deleted_at` for retention |
| notification_outbox.recipient_id / actor_id → profiles | cascade / set null | |

K16 test: build a populated graph (user with projects, members, requests in all states, chats, photos, reports both ways), delete, assert every row's outcome.

### 4.4 Request state machine and duplicates

```
(none) ──send_request──► PENDING ──respond(accept)──► ACCEPTED   [final]
                            ├──respond(decline)──► DECLINED       [final]
                            ├──withdraw (sender) / block / account deletion──► WITHDRAWN [final]
                            └──expiry job or lazy read; project leaves PUBLISHED; seat filled or removed;
                               request hidden by moderation──► EXPIRED [final]
```

- Recipient: join → project owner; invite → invitee (sender must own the project); collaborate → the person (project optional; message required if no project) (D36). Request form fields per FIG-V `1480:4806`: role, time commitment, notes (= message); the payment block is dropped (D12).
- **Duplicates (C-25, X-09).** Unique `(pair_low, pair_high, project_id) nulls not distinct where status = 'pending'` (PG ≥ 15; local stack is PG 17, `R-BE §7.3`): one pending request per pair per project, either direction. RPC checks also refuse: a pair+project with an accepted request (`duplicate_request`); a collaborate request when the pair already has an open conversation ("already in your Crew"); a re-request within 90 days of a decline for the same sender→recipient→project [design]. `send_request` replays by `op_id`.
- Terminal states are final (trigger); clients hold no UPDATE grant.

### 4.5 Acceptance: authorization, locking, races (X-01, X-02, C-04, C-05)

**Global lock order** (every RPC and job takes a subset, always ascending):
0. Profile rows of the parties, `FOR SHARE`, ascending id (`begin_account_deletion` and reviewer suspension take `FOR UPDATE`).
1. Pair advisory lock `pg_advisory_xact_lock(hashtextextended(pair_low::text || pair_high::text, 0))` (send, respond, withdraw, block, unblock).
2. Project row `FOR UPDATE` (respond for project kinds, project RPCs, expiry job per project with `skip locked`).
3. Seat row (`project_roles`) `FOR UPDATE`.
4. Request row `FOR UPDATE`.
5. Conversation row `FOR UPDATE` (accept, block) or `FOR SHARE` (message insert trigger).

**`respond_request(accept)` re-validates after taking locks:**
- Request `pending`, not hidden, `expires_at > now()` (a deadline passed before the cron is still refused, X-01).
- Caller is the recipient; both parties exist (not null), `active`, eligible, not `deleting`/`suspended`; not blocked either way (blocked → `not_found`).
- Caller is request-ready (4.8).
- Project kinds: project exists, `published`, not hidden, `expires_at > now()`; seat row has `project_id = requests.project_id` (also enforced by the composite FK); for `join_project` the caller still owns the project; for `invite_to_project` the sender still owns it.
- **Seat filler**: `join_project` → sender; `invite_to_project` → recipient (caller). Filler is not already a member.
- **Atomic seat claim**: `update project_roles set status = 'filled', filled_by = :filler where id = :seat and project_id = :project and status = 'open' returning id`; zero rows → `seat_taken`. Unique `project_members (project_role_id)` is the backstop.
- Then: status `accepted`; reuse the pair's open conversation or create a new generation; participants; `project_members`; other pending requests on that seat → `expired`; no open seats left → project `closed(filled)` and its pending requests → `expired`; set `taste_dirty_at` for both; outbox row for the sender. One transaction.
- Any failed check → typed error (`stale_state`, `seat_taken`, `not_found`, `missing_fields`); replay of an already-accepted request by the same caller with the same `op_id` returns the original success.

**Race tests (two connections, CI `backend` job; 8.4).** accept/accept on one seat (exactly one wins); accept/block (never "accepted with an open conversation while blocked"); accept/close_project; accept/expiry job; accept/begin_account_deletion; send/block; message insert/block (2.6); remove_project_role/accept. Each forces both interleavings with advisory-lock barriers and asserts the invariant.

### 4.6 Project state machine (C-17, C-32)

```
DRAFT ──publish──► PUBLISHED ──last seat filled──► CLOSED(filled) ──complete──► PAST(completed)
  │                   ├──close──► CLOSED(owner_closed) ──complete──► PAST(completed)
delete_draft          ├──complete──► PAST(completed)
                      └──expires_at passes──► PAST(expired) ──renew──► PUBLISHED
hidden_at (moderation) is orthogonal.
```

- `publish_project` contract (`N-DM`, `N-ONB`, Product Requirements): title, description, realm, type (+ other text, filtered), compensation ≠ undecided, work mode, city if local/either, timing (dates or `flexible_timing`), ≥1 open seat, owner publish-ready (4.8); sets `expires_at = now() + 30 days` (accepted OD-13).
- `renew_project` only from `past(expired)`, needs ≥1 open seat; new `expires_at`. **Reopen is cut** (C-18).
- **Invariants on every write**, not only at publish (C-17): while `published`, realm, type, compensation, work mode and city are locked [design]; title, description, cover and timing are editable via `update_published_project`. `remove_project_role` removes only open seats and refuses the last open seat of a published project (owner closes instead); its pending requests → `expired`. A constraint trigger asserts "published ⇒ ≥1 open seat".
- Leaving `published` expires the project's pending requests.
- Notion's 8 product statuses map as in v1 Appendix A row 8.

### 4.7 Account lifecycle and deletion (X-05, X-13, X-25, C-20, D42)

```
ACTIVE ──begin_account_deletion (user or decline_eligibility)──► DELETING ──delete-account completes──► (gone)
ACTIVE ──reviewer──► SUSPENDED ──reviewer──► ACTIVE
```

`delete-account` steps (each idempotent; progress in `private.deletion_jobs`):
1. **Freeze** (`begin_account_deletion`, profile row `FOR UPDATE`): `account_status = 'deleting'`; withdraw all pending requests sent or received; close the user's open conversations; set `messages.sender_deleted_at = now()` on the user's messages; remove the user's `project_members` rows and reopen seats; delete device tokens. From this commit on, `caller_ok()` is false for every stale JWT on every device, so PostgREST, RPCs, Storage uploads and Realtime events all refuse the account (X-05). The function then revokes refresh tokens (`/logout?scope=global` with the caller's JWT) so other devices cannot refresh.
2. **Apple (X-13).** At the "Delete account" confirmation, Apple users re-authenticate with Sign in with Apple and the app sends the fresh `authorizationCode`. The function exchanges it at Apple's token endpoint with a client secret signed by the Apple key and calls `/auth/revoke` (TN3194, cited by X-13). Only if no code is available (e.g. job-resumed deletion) does it fall back to TN3194's manual instructions, recorded as `apple_revocation = 'manual'`. Needs the Apple key (D39): until then K16 tests the exchange against a mocked endpoint.
3. **Storage.** List and remove `avatars/<uid>/` and `user-media/<uid>/` via the Storage API until empty (uploads are already refused).
4. **Auth.** `auth.admin.deleteUser(uid)`; cascades per 4.3.
5. **Client.** `signOut(scope: .local)`, cancel `SessionScope`, purge caches, show "Your account was deleted".

`resume-deletions` (hourly) re-invokes the function via the job secret for rows `deleting` for > 1 h. **D42 retention:** UI shows "Deleted user" for null senders; `erase-deleted-message-text` (daily) sets `body = null, erased_at = now()` where `sender_deleted_at < now() − 30 days`; erased messages show "Message removed". Report evidence that contains the deleted user's message text is erased on the same schedule unless the report is open/reviewing, in which case 30 days after closure [design; legal confirmation pending, AD]. Other report evidence: 1 year after closure (`N-DM` proposal).

### 4.8 Readiness levels and `missing_fields` (X-19, C-26)

From `N-ONB` "Canonical data contract":

| Level | Required | Gates |
|---|---|---|
| Eligible | verified email (email users; Supabase confirmations), `legal_acceptances.age_confirmed` | everything except own-row reads |
| Browse-ready | eligible + handle + primary_realm | `complete_onboarding`, Home |
| Request-ready | browse + ≥1 role + primary role + availability_band + work_mode + city (if local/either) | `send_request` (collaborate, invite), `respond_request(accept)` |
| Join-ready | request-ready + ≥1 preferred project type + compensation_preference | `send_request(join_project)` |
| Publish-ready | browse + roles + primary role + availability_band + work_mode + city (if local/either) | `publish_project` (plus the project contract) |

`missing_fields(action)` and the RPCs share one SQL function, so the "one sheet" the app shows (`N-ONB` Skip behaviour) asks exactly for what the server will check. `email_not_verified` is reachable only for Apple identities without a verified email claim **[unverified edge case]**; email users cannot hold a session before verifying (`enable_confirmations = true`, C-26).

---

## 5. Main flows, step by step

### 5.1 Onboarding

1. Entry → Create account / Log in (FIG-V `1526:4399`). Email + password (D30); "Continue with Apple" appears once K18 ships (D13, D39); Google removed (D28).
2. **Sign up** → **Verify email** (6-digit code, resend after 60 s) (accepted OD-3).
3. **Terms + 18+** (unticked checkbox "I am 18 or older and agree to the Terms", links to Terms, Community Guidelines, Privacy) → `accept_terms` → `refreshProfile()`. Under 18 → `decline_eligibility` → `delete-account` → stop screen (2.8). **No Skip** on account creation (FIG-V conflict 11).
4. **Handle + display name** (`set_handle`, debounced `handle_available`).
5. **Realm** (O2).
6. **Goal** (FIG-V `1312:12209`, two options): "I want to collaborate" → **Start or Join** follow-up (two options: "Start a project" / "Join a project"); "Explore and get inspired" → `intent = explore`. Keeps Notion's three intents with the Figma two-option screen [design].
7. **Taste cards** (O4, skippable) → **Pairwise** (O5–O7, skippable) → `submit_taste`.
8. **Roles** (O9: 1–3, first is primary).
9. Branch: Start → project type, roles needed, compensation (draft answers in `onboarding_state`); Join → project interests, compensation preference; Explore → discovery focus (`N-ONB`).
10. **Availability** (Start/Join) → **Location primer** (single Continue → system prompt; granted → one-shot reduced-accuracy fix → on-device city suggestion; denied → manual city) → **Work mode + city** (city public, D41) (D8, D31).
11. **Notifications primer** (single Continue → system prompt; denial never blocks). Token registration starts with K17.
12. **Favourites** (optional; consent toggles shown, 2.13) → **Your work** links (optional, two consents off) → **Profile photo** (optional; Blobatar fallback, D9).
13. Loader → **Preview** (C4): `complete_onboarding()` (browse-ready; creates the single onboarding draft for Start users) → `recommend('onboarding_preview', 5)`; fewer than 3 → empty-state copy (`N-ONB` C4) → "Enter Kizuki" → Home. Start users see "Finish your project" (D7).

Every step saves via `save_onboarding_step`; Skip from step 7 onward lands on Home with completed answers only; the missing-fields sheet appears before an action needs them (4.8).

### 5.2 Home feed

1. `recommend('home_projects', 10)` and `recommend('home_people', 8)` in parallel → cards loaded via RLS.
2. Sections: Finish-your-project (D7) → Recommended projects → People you might like (D19). "See more" opens full Projects / People lists (FIG-V `1468:4887`, `1473:5741`) without the For You/Following control (D24).
3. Card actions: like, save, overflow (Not my style, Hide, Report). No star ratings, no comments (D25; FIG-V correction 17).
4. Project → detail → **"Ask to join"** → request form (5.3). Person → profile → **"Ask to collaborate"**.
5. Top bar: Inbox, Settings (D19).

### 5.3 Request / invite → accept → chat → Crew

1. **Compose** (FIG-V `1480:4806` minus payment): role (join/invite), time commitment, notes. Entry points: project detail (join), other profile (collaborate; optional own project), My Projects › project › Invite (invite; pick a person from your Crew, recommendations or a profile).
2. **Send** `send_request(..., op_id)` → checks (4.4, 4.8) → `pending` → outbox → push "New request from @handle" (after K17).
3. **Receive** in Suki › Requests › Incoming → request detail (who, project/role, time, notes; no fit reasons in v0, C-31) → Accept / Decline / Report / Block.
4. **Accept** → 4.5 contract in one transaction → both people see each other in **Suki › Crew** and the conversation in Inbox; push to sender "@handle accepted your request".
5. **Chat** (2.6): subscribe, fetch with overlap, send with `client_id`; header shows project context, Report, Block.
6. Decline (optional private reason; sender sees "Not this time"); withdraw while pending; expire after 14 days.

### 5.4 Suki create chooser (FIG-V `1361:12435`)

- **Get discovered** → update creative profile: realms, roles, project interests, how you want to work, links (FIG-V `1411:3033`, `1418:3514`, `1423:11185`). Writes the same fields as onboarding.
- **Create a project** → form (FIG-V `1361:12567`; "Paid" becomes the compensation label, D12): title, description, realm, type, seats, compensation, work mode, city, time commitment, dates or flexible, cover photo. Saves as draft; Publish → `publish_project`.
- **Post a collab** → system photo picker → caption + tags → renditions, EXIF strip, upload → `collab_photos` (AD) → appears in "My Collabs" and Search.

### 5.5 My Projects

Drafts (owned drafts) · Published (owned published + closed, plus joined projects labelled "Joined") · Past (owned or joined, past). Owner detail: Edit, Publish, Close, Mark done, Renew (expired only), Invite, seats and members.

### 5.6 Search

Grid of visible collab photos, newest first, pages of 30, batch-signed thumbs (10-min URLs). Chips = seeded tags and realms (FIG-V chips). Query = `ilike` on caption and tags plus a people row from handle prefix [design; trigram cut]. Post viewer: image, caption, author, time, like, save, Report, open author profile (FIG-V gap 16). Empty and no-results states.

### 5.7 Profile

Own profile: avatar, name, @handle, primary role + realm, public city, bio, roles, favourites (if shown), links/embeds, collab photos, projects, **Edit**. Other profile: same + "Ask to collaborate" + Report/Block; no Follow, no follower counts (D24). Availability/work mode are not shown on other people's profiles (owner-only, 2.10) [design; FIG-V shows an availability card, so the design round decides whether to drop it or propose making it public].

### 5.8 Report and block

Report from any UGC overflow → category → optional context → `submit_report` → "Thanks. We review reports within 24 hours." + "Also block". Item stays hidden for the reporter (persisted). Block from profile, chat header or report confirmation → 2.11 side effects; blocked people listed in Settings › Privacy & Safety with Unblock.

### 5.9 Delete account

Settings › Account › Delete account → explanation (D42: "Your messages stay visible to the people you sent them to as Deleted user for 30 days, then the text is erased") → re-authenticate (email: password; Apple: Sign in with Apple, providing the authorization code) → confirm → `delete-account` (4.7) → signed out → "Your account was deleted". Apple fallback copy only when revocation could not run.

---

## 6. v0 vs later

**v0 exit criteria (every locked feature; nothing here may slip without a user decision, X-24):**
- Email/password with code verification and code recovery; Sign in with Apple (D13, D30; device verification after D39).
- Terms + 18+ gate first, server-enforced; handle 3–20 (AD).
- Onboarding with permission primers up front (D8, D31), taste cards with placeholder art and pairwise choices (D21), favourites picker (D22), roles, branches, availability, work mode + public city (D41), links, photo, preview.
- Home feed (projects + people, Finish-your-project), Search grid (D19), Suki **Crew** + Requests + create chooser (D19, D40, D44), My Projects (D19), Profile with embeds (D23), Inbox and Settings from Home (D19), system icon-only tab bar (D32).
- Requests both ways → accept → direct chat (D11, D36, accepted OD-2); real APNs push for request, acceptance, message (D35).
- SQL `recommend` with Notion v1 components, threshold, privacy-safe reasons, cold start (D15, accepted OD-1).
- Likes/saves private (D25, accepted OD-8); report + block, auto-hide at 3 qualifying reporters, daily review, text filter (D16, D34, accepted OD-6, OD-11).
- Delete account with D42 retention and Apple revocation contract; avatars with Blobatar fallback (D9).
- Staging seeded with fictional data (D18, D29, D38); TestFlight once enrolment exists (D39).

**Cut from v0, not required by any locked decision (C-18):** serendipity mix + O8 screen, exposure floor, MMR, jitter, complementarity bonus, adaptive pairwise follow-ups, recommendation set logging, reopen, trigram search, "For you" chip, a third storage bucket, fit reasons on request detail.

**Later (unchanged from v1):** Google sign-in, payments, follows/Following, comments, star ratings, events, Made Together, appeals tooling, Suki AI assistant, group chat, attachments, edit/unsend, Broadcast chat, pgvector and Edge Function ranker, weekly re-fit, reference catalogue, link validation/recheck, Instagram embed, Letterboxd/Spotify import, analytics and crash vendor, `export-account` (launch blocker), handle rename/hold, deactivation, Universal Links, image moderation API, server image transforms, real users, production writes, commercial TMDB/MusicBrainz licences.

---

## 7. Risks, open decisions, least sure

### 7.1 Risks, ranked

| # | Risk | Mitigation in v2 |
|---|---|---|
| 1 | **Scope.** Still 20 slices, ~35 tables, 13 targets, 3 functions, ~70 screens for a solo agent-built v0. | Cuts in 6; thin K01; core loop by K08b; every later slice has a fixed exit criterion; Codex reviews per slice catch drift early. Independent verification of v2 should re-attack scope. |
| 2 | **Definer code and concurrency.** `recommend`, RPCs, storage policies and helpers bypass RLS; acceptance and block interleave. | Helpers return booleans/IDs only; one lock order (4.5); atomic seat claim; pgTAP visibility matrix; two-connection race suite in CI. |
| 3 | **Apple chain parked** (D39; D33 organisation + D-U-N-S lead time **[unverified duration]**). Blocks TestFlight, Apple sign-in on device, APNs on device, Apple revocation verification. | Those parts are contract-tested with mocks; K17, K18, K20 device checks gate only on D39. Recommend starting enrolment before K16. |
| 4 | **Live test coverage without local Docker.** macOS runners cannot run the Supabase stack **[unverified for macos-15 arm64; GitHub's hosted macOS arm64 runners are documented as lacking nested virtualization]**; ticket 005 open. | 8.4: live suites on Linux, recorded HTTP contracts replayed by Swift tests, manual live pass on a developer Mac once 005 closes and on staging at K19. |
| 5 | **Apple 1.2 image filtering** under accepted OD-11 (no hold-for-review). | Report everywhere, auto-hide, daily review, text filter, Terms + Community Guidelines, reportable seed item for the reviewer. Revisit if Beta App Review objects. |
| 6 | **Email delivery and auth config on staging.** 2 emails/hour without SMTP; `config push` support unverified; OD-15 pending. | Seeded users are pre-confirmed; real sign-ups wait on OD-15; dashboard checklist fallback (3). |
| 7 | **Taste is noise in v0** (placeholders, provisional facets, ticket 007). | Cold-start rule; `similar_taste` reason gated off until facets are real. |
| 8 | **Account linking** may merge silently (X-14). | Spike in K18; disclose + Undo; OD-17. |
| 9 | **Staging plan.** Free projects pause when idle **[unverified threshold]**; App Review needs a live backend. | OD-16. |
| 10 | **Vault + `pg_net` + pg_cron** behaviour on the local CLI stack and hosted staging **[unverified for this project]**. | K17 starts by proving the trigger fast path and the cron drain on the CI stack. Fallbacks: no trigger fast path → cron drain only (≤ 1 min latency); no cron → function calls → a scheduled GitHub Actions job runs the drain against staging through `kz-remote.sh`. |
| 11 | **Undesigned screens** (Crew, Requests, My Projects, email screens, delete account). | Ticket 009 prototype before K08a; placeholder tokens until the design round. |
| 12 | **Third-party terms** (TMDB commercial, SoundCloud own content, Bandcamp path). | Launch gates, not TestFlight gates (`R-IOS §9`). |
| 13 | **Chat reliability** (reconnect, late commits). | Overlap fetch + dedupe (2.6); airplane-mode test in K08b. |

**Locked decisions I would still question (not re-opened):** D8/D31 up-front permissions (HIG prefers in context, `R-IOS §2.1`; Notion defers, `N-ARCH`); D35 real push in v0 (most of it unverifiable until D39); D21 taste cards with placeholders (output meaningless until ticket 007); D33 + D39 together put TestFlight behind a legal process. D42 is now implemented as decided (4.7).

### 7.2 Open decisions

Resolved since v1 (no longer open): OD-4 → D41, OD-5 → D43, OD-7 → D42, OD-14 → D40/D44; OD-1, 2, 3, 6, 8, 9, 10, 11, 12, 13 accepted by default.

| # | Decision | Options | Recommendation |
|---|---|---|---|
| OD-15 | Email sending domain, SMTP provider, support address | user to supply | Pending from user. Blocks real sign-ups on staging, MusicBrainz User-Agent, support URL, Terms/Privacy hosting |
| OD-16 | Staging Supabase plan | **A) Free while building, Pro before external TestFlight**; B) Pro now; C) Free throughout | **A.** Free is enough for agents and seeded tests; Pro avoids pausing during Beta App Review and may enable leaked-password protection and PITR **[unverified plan features and price]** |
| OD-17 | Apple/email identity collision | **A) Accept Supabase's automatic link, disclose it immediately with Undo**; B) refuse Apple sign-in on collision and require email login first (Notion's exact rule; feasibility unknown) | **A**, unless the K18 spike shows B is supported |
| OD-18 | Favourites used for matching by default | **A) On, with a visible toggle on the picker**; B) off until the user opts in | **A.** The picker's stated purpose is matching (D22); display stays off by default |
| OD-19 | Availability and work mode on other people's profiles | **A) Owner-only (Notion)**; B) public, as Figma's availability card shows | **A** for now (coordinator instruction, `N-DM`); revisit in the design round |
| OD-20 | Report evidence about a deleted user | **A) Erase their message text 30 days after deletion unless the report is open, then 30 days after closure**; B) keep evidence 1 year after closure (`N-DM`) | **A**, pending legal input (AD "report retention pending legal") |

### 7.3 What I am least sure of

1. Whether 20 slices is still too much for "ship when it works" (Risk 1).
2. Whether hosted Supabase supports what the contracts assume: no silent identity linking (OD-17), `config push` for auth settings, Vault + `pg_net` from triggers and cron.
3. Whether the recorded-contract approach (8.4) catches enough Swift↔backend drift without a live iOS run in CI.
4. The goal-screen mapping (two Figma options → three Notion intents via a follow-up question) is my design guess.
5. Whether a 10-minute signed-URL TTL is acceptable for scroll performance and request volume in Search.

---

## 8. Build plan and test strategy

### Plain language

Twenty small pieces. Each one adds its database tables before anything uses them and ends with a test that runs the whole slice. The first nine make the core loop real for an email user: sign up, onboard, publish, get recommended, request, accept, become Crew, chat. Safety comes straight after, then the rest of v0. Nothing locked can be dropped quietly.

### 8.1 Rules for every slice

- One slice = one ticket on the Wayfinder map (`docs/map/tickets/NNN-<slug>.md`, proposed 012–031).
- **Wave 0 freezes only the core-loop contracts** (Swift models + repository protocols + RPC signatures for K04–K08b), reviewed by an independent agent; later slices extend contracts with their own contract review (C-19; [[playbook]] §7).
- Schema before consumers: a slice may only call tables and RPCs created by itself or an earlier slice (X-23).
- Done = its tests in 8.4 green in CI + screenshots via the launch-argument router + every new UGC surface has Report + the platform prerequisites it uses (purpose strings, entitlements) are in place (X-22).
- **Cross-model review (playbook rule 1, D45).** Every slice changes 3+ files, so every slice gets a review by the other model family before merge. Builder alternates by complexity and usage (D45); the reviewer is always the other family. Risk classes mark where a miss costs most: **AUTH**, **DELETE**, **PRIVACY** (definer code, RLS, storage, locking), **ENV** (remote projects, secrets). Max two review rounds; leftovers become tickets (playbook rule 4).

### 8.2 Slices

| ID | Slice and end-to-end proof | Depends | HITL | Risk |
|---|---|---|---|---|
| **K01** | **Thin shell.** `AppTab`/`AppRouter`/`AppRoute`, 5-tab `TabView` with placeholder roots, Home top bar (Inbox, Settings placeholders), launch-arg router, `KizukiTestSupport` (`#if DEBUG`) with core-loop fixtures only, move `UITestBackend`, drop global dark lock. *Proof:* UI test visits every tab and route. | — | — | 3+ files |
| **K02** | **Backend backbone + test harness.** Enums, taxonomies, `private` schema + helpers + grants, profile/settings extensions (public city), `legal_acceptances`, `blocked_terms` trigger, `op_results`, environment marker table (empty), seed generator skeleton + local loader, `[db.seed]`, `[storage]`, `[edge_runtime]` enabled; CI `backend` job with pgTAP, Python two-connection harness, Deno test runner, migration grep checks. *Proof:* CI green with pgTAP for helpers/grants and one sample race test. | — | — | PRIVACY |
| **K03** | **Environment pinning.** Staging allowlist in `AppConfiguration` + validator; Production refused in v0; `Staging.xcconfig` → `club.kizuki.ios` + staging URL (D43); `scripts/remote/kz-remote.sh` gateway with marker check; CI rule against remote commands elsewhere. *Proof:* Swift + Python tests incl. the unapproved-ref probe; gateway dry-run refuses other refs. | — | Staging publishable key (D38) for a real build | ENV |
| **K04** | **Email auth + eligibility + minimal deletion.** Sign-up, verify code, sign-in, sign-out, recovery by code, root phases + `refreshProfile`, `SessionScope`; Terms/18+ first with `caller_ok()` enforcement; `decline_eligibility`, `begin_account_deletion`, auth-only `delete-account`, `purge-abandoned-signups`; email templates; Terms/Community Guidelines links. *Proof:* live suite: sign-up → Mailpit code → verify → ineligible reads denied → accept terms → recovery flow; under-18 deletes the account; fixture UI test of every auth screen; contract replay. | K01–K03 | OD-15 for staging mail | **AUTH + DELETE** |
| **K05** | **Onboarding core.** Handle, realm, goal + start/join, roles, branches, availability, location primer (purpose strings here), work mode + public city, notifications primer (permission only), `save_onboarding_step`, `missing_fields`, `complete_onboarding` (browse-ready; draft answers kept in `onboarding_state`). *Proof:* pgTAP readiness levels; live resume after relaunch; UI tests for three paths and permission denial. | K04 | — | 3+ files |
| **K06** | **Projects + My Projects.** Projects, seats, members, all project RPCs + invariants, expiry job, onboarding draft materialisation (`complete_onboarding` now creates the Start draft idempotently), create form (no cover yet), owner/visitor detail, My Projects segments. *Proof:* pgTAP state machine incl. illegal transitions and locked fields; live create → publish → expire → renew; UI. | K05 | — | PRIVACY |
| **K07** | **`recommend` + Home.** Weights, Stage 0/2/3 with cold start, privacy-safe reasons, feedback RPCs, Home sections, see-more lists, C4 preview. *Proof:* golden pgTAP fixtures (2.10) incl. zero-taste and privacy assertions; UI on fixtures; contract replay. | K06 | — | **PRIVACY** |
| **K08a** | **Requests + Crew.** Requests, decline reasons, conversations + participants schema, send/respond/withdraw with the 4.5 contract, request form (role, time, notes), Suki Crew + Requests in/out + request detail, Invite from My Projects. *Proof:* pgTAP transition matrix; **race suite** (accept/accept, accept/close, accept/expiry, send/withdraw); live two-user script send → accept → both see Crew. | K07 (entry from Home), K06 | 009 prototype review | **PRIVACY** |
| **K08b** | **Chat.** Messages + trigger, Realtime publication, `ChatTransport`, Inbox, chat screen, unread dot, mark_read, mute. *Proof:* live two-client Realtime test (send, late-commit overlap, reconnect refetch, dedupe); race message/close; fixture UI. **Core loop complete.** | K08a | — | PRIVACY |
| **K09** | **Safety.** Blocks + side effects (incl. memberships, conversation generations), unblock, blocked list, reports split, invoker `submit_report`, moderation columns + auto-hide with qualifying reporters, Report on every existing surface. *Proof:* pgTAP both-direction visibility matrix on every read path so far; race accept/block, send/block, message/block; live block-then-unblock-then-new-request opens a new conversation. | K08b | — | **PRIVACY** |
| **K10** | **Storage, avatars, project covers.** `avatars`, `user-media`, `taste-cards` buckets and policies, path CHECKs, renditions + EXIF strip, avatar in onboarding/profile, cover in project form, scoped cache. *Proof:* pgTAP storage policies; live upload/sign/block/deleting-account tests. | K09 | — | PRIVACY |
| **K11** | **Search + Post a collab.** `collab_photos`, Suki chooser (Get discovered / Create a project / Post a collab), post flow, grid, chips, query, post viewer with actions. *Proof:* live post → grid → hidden by auto-hide; UI. | K10 | — | 3+ files |
| **K12** | **Profile + links/embeds.** Own/other profile, edit, "Get discovered" form, `portfolio_sources` + host trigger, `KizukiEmbeds`. *Proof:* parser unit tests (hostile URLs); live consent visibility; provider smoke checklist on device with authorised public URLs. | K10 | — | 3+ files |
| **K13** | **Taste cards + pairwise.** Taste tables, placeholder art, `submit_taste` (replace semantics), `recompute_taste` from sources, taste in `recommend`, taste reasons gate. *Proof:* pgTAP maths vs hand-computed values; replay produces identical facets; skip path; golden fixtures re-run. | K07, K10 (bucket) | 007 improves, does not block | 3+ files |
| **K14** | **Favourites.** `tmdb-proxy`, MusicBrainz client, favourites + two consents, `shared_favourite` reason, TMDB attribution. *Proof:* Deno tests (auth, throttle); Swift queue tests; pgTAP rarity population and consent-off removal. | K13 | TMDB key; OD-15 for User-Agent contact | ENV |
| **K15** | **Settings + legal + support.** Settings root, notification preferences, privacy & safety, legal pages (Terms, Community Guidelines, Privacy, YouTube ToS), support, sign out with token unlink. *Proof:* UI; live preference affects `send-push` eligibility after K17. | K09 | OD-15 | 3+ files |
| **K16** | **Full deletion + retention.** Storage purge, refresh-token revocation, job-secret path, `resume-deletions`, D42 erasure job, report-evidence retention, FK graph test, Apple revoke against a mocked endpoint. *Proof:* populated-graph deletion test; stale JWT refused on PostgREST, Storage and Realtime; erase job at day 30 (time-travel test). | K10, K15 | Apple key for real revoke (D39) | **DELETE + AUTH** |
| **K17** | **Push.** Device tokens (reassign, unregister), outbox with lease/retry/dedupe, Vault-based fast path + cron drain, `send-push` with secret, delivery re-checks, tap routing, foreground suppression, Push capability. *Proof:* pgTAP outbox rows; Deno tests (user JWT rejected, forged body ignored, 429 retry, 410 token removal, duplicate claim); device push after D39. | K08b, K15 | **D39 + APNs key** for device | **ENV + PRIVACY** |
| **K18** | **Sign in with Apple.** Identity-linking spike first; nonce flow; entitlement; name capture; disclosure + Undo (OD-17); authorization code captured for deletion. *Proof:* unit tests; device sign-in after D39. | K04, K16 | **D39** | **AUTH** |
| **K19** | **Staging deploy + seed.** Full generator volumes (11), `load_staging.py`, marker bootstrap, migrations/functions/secrets/Vault/auth config via the gateway, staging smoke checklist (every flow on a simulator against staging). | K01–K17 | Staging key (D38), OD-15, OD-16 | **ENV** |
| **K20** | **Release plumbing + TestFlight.** Privacy manifest, export compliance key, 18+ rating, App Store Connect record, privacy answers, review notes, demo account, archive/upload script, Production guard flip stays off. | All | **D39**, D33 | ENV |

### 8.3 Dependency graph

```
K01 ─┐
K02 ─┼─► K04 ─► K05 ─► K06 ─► K07 ─► K08a ─► K08b ─► K09 ─┬─► K10 ─┬─► K11
K03 ─┘                                                   │        ├─► K12
                                                         │        └─► K13 ─► K14
                                                         └─► K15 ─► K16 (also K10) ─► K18 (also K04)
                                       K08b + K15 ─► K17
                                       K01–K17 ─► K19 ─► K20
```

Critical path: K01–K03 → K04 → K05 → K06 → K07 → K08a → K08b → K09 → K10 → K16 → K19 → K20. After wave 0, up to three lanes run without overlapping files (e.g. K11/K12/K13 after K10; K15 beside K10) ([[playbook]] §8).

### 8.4 Test strategy: what proves S03–S08 (now K04–K08b) end to end (C-13, X-28)

Constraint: no local Docker yet (ticket 005); the `ios` CI job runs on `macos-15`, where the Supabase stack cannot run **[unverified: hosted macOS arm64 runners lack nested virtualization]**; the stack runs on the `ubuntu-latest` job.

| Layer | Runs where | Proves |
|---|---|---|
| 1. pgTAP | CI `backend` (ubuntu, Docker); locally with the native runtime today | Policies, grants, helpers, RPC checks, state machines, golden `recommend`, visibility matrix, readiness |
| 2. Two-connection race suite (Python, psycopg, advisory-lock barriers) | CI `backend` | 4.5 invariants under both interleavings |
| 3. Live API suite (Deno + supabase-js, two or more signed-in users; Mailpit for codes; Realtime; Storage; Edge Functions via `supabase functions serve`) | CI `backend` | Each core-loop slice end to end against real Auth, PostgREST, Realtime, Storage, functions: sign-up/verify/recover, onboarding resume, publish, recommend, send → accept → Crew → message live, block/unblock, deletion with stale JWT |
| 4. Recorded HTTP contracts | Recorded by layer 3 into `ios/Tests/Contracts/*.json`; replayed on CI `ios` (macos) by Swift `URLProtocol` tests (the existing `SupabaseBackendTests` pattern) | The Swift repositories send exactly the requests the live backend accepted and decode exactly what it returned. A drift check fails CI if a recorded contract changes without the Swift tests changing |
| 5. XCUITest on fixtures | CI `ios` | Every screen and flow, permission denial paths, Dynamic Type spot checks |
| 6. Manual live passes | Developer Mac after ticket 005 (simulator against local stack); staging at K19 (simulator); device after D39 | The app against a real backend: the one thing layers 3–5 only prove indirectly. Checklist with screenshots per slice |
| 7. Provider smoke | Device, K12 | YouTube/SoundCloud/Bandcamp playback with real, public, owner-authorised URLs |

Exit rule for each of K04–K08b: layers 1–5 green in CI, plus layer 6 on whichever live target exists at the time (local once 005 closes, otherwise staging once K03 + D38 key are in place). If neither exists, the slice merges on layers 1–5 and the manual pass becomes a blocking item for K19.

---

## 9. Screen list per tab (structure only, no look)

Node IDs refer to the canonical copy `nPqXTMCtd3OVZTSU7Y2uN3` (same IDs as the original per FIG-V header; C-29). "NEW" = no Figma frame (D26). Every list has loading, empty and error states. Out of scope everywhere: star ratings, comments, follow/followers, payment blocks, "anyone can message" (D12, D24, D25, D28; FIG-V conflicts).

**Entry and onboarding**
1. Splash (`1312:11087`)
2. Create account / Log in (`1526:4399`)
3. Email sign-up — NEW
4. Email log-in — NEW
5. Verify email (code, resend) — NEW
6. Forgot password: email → code → new password — NEW
7. Sign in with Apple button (from K18) on screens 2–4 (`1312:11854` minus Google)
8. Terms + 18+ (age block of `1480:4256`, reworded; no Skip) + under-18 stop screen — NEW
9. Handle + display name (`1480:4256` name/username part; errors `1480:4367`)
10. Realm (`1344:11498`, `1344:11806`; realm-specific options replace the film-only placeholder lists)
11. Goal: "I want to collaborate" / "Explore and get inspired" (`1312:12209`)
12. Start or Join follow-up (two options) — NEW
13. Taste cards O4 (intro art from the illustrations file; picker NEW)
14. Pairwise choice O5–O7 — NEW
15. Roles O9 (`1336:16105`)
16. Start: project type, roles needed, compensation (`1336:15975` + NEW)
17. Join: project interests, compensation preference — NEW
18. Explore: discovery focus — NEW
19. Availability (from work prefs `1312:12351` "Time") — NEW layout
20. Location primer, single Continue (`1312:13188` restructured: it currently shows a notifications alert, FIG-V correction 4)
21. Manual city search — NEW
22. Work mode (`1312:12351` "Mode")
23. Notifications primer, single Continue — NEW
24. Favourites picker with display + matching toggles — NEW
25. Your work: links, relation, two consents (`1312:12814`)
26. Profile photo (`1587:4579`, crop `1312:11996`)
27. Loader (`1312:11134`)
28. Preview C4 / empty state (`1312:11364`; welcome art must be replaced, FIG-V conflict 10)

**Tab 1 — Home**
1. Feed: Finish-your-project, Recommended projects, People you might like (`1312:8064`, `1467:4643`)
2. Projects list, People grid via "see more" (`1468:4887`, `1473:5741`, without For You/Following)
3. Project detail, visitor: roles/seats, timing, compensation label, collaborators, owner, "Ask to join" (`1449:4146`, `1485:5384`, `1449:4691` minus comments/ratings; closed `1485:6118`)
4. Request form: role, time commitment, notes (`1480:4806` minus payment block)
5. Missing-fields sheet — NEW
6. Inbox (`1312:10492`, empty `1312:10709` without "New message" and message-requests folder)
7. Chat with project header, Report, Block (`1312:10374`)
8. Settings root (`1312:8654`) → Profile & Account (`1312:8799` minus mobile phone; + Sign out, Delete account), Notifications (`1312:8901`), Privacy & Safety (`1312:9053`; "Who can message me" removed; + Blocked accounts), Help & Support (`1312:9248`), Legal & About (`1312:9294`; + Community Guidelines, TMDB credit)
9. Delete account: explain → re-auth → confirm → done — NEW
10. Blocked accounts — NEW
11. Report sheet + confirmation with "Also block" — NEW (shared)

**Tab 2 — Search**
1. Grid + chips (`1312:9342`)
2. Post viewer with author, time, like, save, Report, open profile (`1468:5306`, `1473:5533` + actions NEW)
3. Query + people row + Recent (`1312:9406`)
4. No results — NEW

**Tab 3 — Suki** (Crew, requests, create; D19, D40, D44)
1. Suki home: **Crew** / **Requests** / Create — NEW (landing art `1361:12184` for the Create empty state)
2. **Crew** list (accepted connections; each opens its chat and profile) — NEW
3. Requests: Incoming / Sent with status — NEW
4. Request detail: Accept / Decline / Report / Block; sent view: Withdraw — NEW
5. Decline sheet (optional private reason) — NEW
6. Create chooser: **Get discovered** / **Create a project** / **Post a collab** (`1361:12435`)
7. Get discovered: intro + creative-profile form + connect links (`1411:3033`, `1418:3514`, `1423:11185`)
8. Create a project form (`1361:12567`; "Paid" → compensation label; "Avaiable" status removed)
9. Post a collab: photo picker → caption + tags (`1385:9327`) → My Collabs (`1418:3318`)

**Tab 4 — My Projects** (all NEW)
1. Drafts / Published / Past segments
2. Owner project detail: Edit, Publish, Close, Mark done, Renew, Invite, seats and members
3. Project editor (reuses Suki form; locked fields while published)
4. Invite sheet (pick a person, pick a seat)
5. Publish errors (field list)

**Tab 5 — Profile**
1. Own profile: header with Edit, roles, public city, bio, favourites, links/embeds, collab photos, projects (`1312:10251` with an own-profile header NEW)
2. Other profile: "Ask to collaborate", Report/Block; no Follow/followers (`1312:9852`, `1312:10050`, `1312:10189`)
3. Edit profile — NEW (fields from `1418:3514`)
4. Edit links (`1423:11185`)
5. Embed player sheet — NEW
6. Edit favourites (picker reuse)

---

## 10. Diagram specs for Archify (one agent per diagram)

No colours or fonts; Archify defaults. Plain labels; technical names as subtitles. Use "Crew" for accepted connections everywhere; never "Matches".

### 10.1 System overview

- **Groups:** Device; Supabase staging `ankgfqkgflcalmlreetu` (Auth, PostgREST + RLS, RPC functions, Realtime, Storage, Vault, pg_cron + pg_net, Edge Functions); Apple (Sign in with Apple, APNs); Third parties (TMDB, MusicBrainz, embed players); a detached greyed node "Production enosggckdxjiaqtxalhg — refused by every v0 tool".
- **Nodes:** iOS app ("SwiftUI · KizukiKit · SessionScope"); Auth ("email + code, Apple"); Postgres ("RLS · caller_ok · is_blocked · lock order"); RPC functions ("requests · projects · recommend · block · report · deletion freeze"); Realtime ("messages, RLS per event"); Storage ("avatars public · user-media private · taste-cards"); notification_outbox ("lease, retry, dedupe"); pg_cron ("expire, drain outbox, erase text after 30 days, resume deletions"); Vault ("function URLs + secrets per environment"); Edge: send-push ("server secret only"); Edge: delete-account ("user JWT or job secret"); Edge: tmdb-proxy; APNs; Sign in with Apple; TMDB; MusicBrainz; Embed players; Remote gateway `kz-remote.sh` ("staging ref only").
- **Edges:** app→Auth; app→Postgres "reads + own writes"; app→RPC "state changes"; app↔Realtime "new messages"; app→Storage "upload, signed URLs (10 min)"; app→delete-account; delete-account→Storage "remove files"; delete-account→Sign in with Apple "revoke token"; delete-account→Auth "delete user"; Postgres triggers→outbox; outbox→send-push "pg_net fast path"; pg_cron→send-push "drain every minute"; Vault→pg_net "URL + secret"; send-push→APNs→app; app→tmdb-proxy→TMDB; app→MusicBrainz "direct, 1 req/s"; app→Embed players "on tap only"; gateway→Supabase staging "migrations, functions, secrets, seed (marker checked)".

### 10.2 Main user flow: request → accept → Crew → chat (sequence)

- **Participants:** Ana (iPhone); Database (RPC + RLS + locks); Push (outbox, cron, send-push, APNs); Ben (iPhone).
- **Steps:**
  1. Ana → DB: "Ask to join · seat Editor · time 5–10 h · note" (`send_request`, op_id).
  2. DB note: "eligible · request-ready · not blocked · one pending per pair+project · seat open · pay compatible · daily limit".
  3. DB: "request = pending; outbox row".
  4. Push → Ben: "New request from @ana".
  5. Ben → DB: "Accept" (`respond_request`).
  6. DB note (one transaction, locks: profiles → pair → project → seat → request → conversation): "re-check expiry, accounts, block, project published, seat belongs to project · claim seat atomically · open or reuse conversation · Ana becomes member · Ana and Ben are Crew".
  7. Push → Ana: "@ben accepted your request".
  8. Ana → DB: "Send message (client_id)"; DB → Ben: "Realtime: new message"; Push → Ben "New message from @ana" (banner suppressed if Ben has that chat open).
- **Alt frames:** "Decline" (private reason, no chat); "Seat already taken" (`seat_taken`, request expires); "Blocked" (`not_found` to the blocked side); "No answer in 14 days" (expired); "Project closed while pending" (expired).

### 10.3 State machines (three panels)

- **Request:** Start → Pending "send"; Pending → Accepted "accept (recipient, re-validated)"; Pending → Declined "decline"; Pending → Withdrawn "withdraw · block · account deletion"; Pending → Expired "14 days · project left Published · seat filled or removed · hidden by moderation". Note on finals: "no further changes (trigger)". Note: "three kinds: ask to join · ask to collaborate · invite".
- **Project:** Draft → Published "publish"; Published → Closed "last seat filled / owner closes"; Published → Past "expired"; Published → Past "mark done"; Closed → Past "mark done"; Past(expired) → Published "renew"; Draft → deleted. Note: "Hidden by moderation applies to any state". Note: "no reopen in v0".
- **Account:** Active → Deleting "delete account / under 18"; Deleting → Gone "files removed · Apple token revoked · auth user deleted"; Active ↔ Suspended "reviewer". Note on Deleting: "all writes and reads of others refused for every device". Side note: "messages stay as 'Deleted user' for 30 days, then text erased".

### 10.4 Data model (ER)

- **Groups and entities (3–5 key fields):**
  - Who you are: profiles (id, handle, primary_realm, city, account_status); profile_settings (private: intent, availability, work_mode, compensation_preference, favourites_for_matching); legal_acceptances; profile_roles; favourites; portfolio_sources; device_tokens (token PK).
  - Taxonomy: roles, project_types, cities, facet_catalog.
  - Taste: taste_items, taste_item_facets, taste_pairs, taste_seed_selections, taste_seed_shown, pairwise_answers, taste_facets (derived).
  - What you make: projects (owner, status, closed_reason, expires_at); project_roles (seat: open/filled, filled_by); project_members; collab_photos.
  - How you connect: requests (kind, sender, recipient, pair key, project, seat, status); request_decline_reasons; conversations (pair key, closed_at = generation); conversation_participants (last_read_seq); messages (seq, sender, sender_deleted_at, erased_at); notification_outbox.
  - Safety: blocks; reports; report_evidence (private).
  - System: op_results, deletion_jobs, environment_marker, ranking_weights, app_config (private).
- **Relationships:** profiles 1–1 profile_settings; profiles 1–N profile_roles N–1 roles; profiles 1–N favourites, portfolio_sources, collab_photos, legal_acceptances, device_tokens, taste_facets; profiles 1–N projects; projects 1–N project_roles; project_roles 1–0..1 project_members; requests N–1 profiles (sender, set null), N–1 profiles (recipient, set null), N–1 projects, N–1 project_roles (composite with project), 0..1 conversation; conversations 1–N participants, 1–N messages; profiles N–N profiles via blocks; reports 1–1 report_evidence.
- **Badges:** "private (owner only)" on profile_settings, legal_acceptances, taste_*, device_tokens, request_decline_reasons; "RPC-only writes" on requests, conversations, project_members, project_roles, blocks, reports; "service role only" on notification_outbox, report_evidence, op_results, deletion_jobs; "public" on profiles.city.

### 10.5 Build roadmap (swimlanes)

- **Lanes:** iOS; Backend (SQL); Edge Functions; Environments & release; Tests & CI; Human-in-the-loop.
- **Phases:** A Foundations (K01, K02, K03) → B Core loop (K04, K05, K06, K07, K08a, K08b) → C Safety and content (K09, K10, K11, K12, K13, K14, K15) → D Account and platform (K16, K17, K18) → E Ship (K19, K20).
- **Cards:** "Kxx · name · risk class · reviewer = other model". Arrows per 8.3.
- **Milestones:** after K08b "Core loop works end to end (email user)"; after K09 "Safety in place"; after K19 "Staging seeded and smoke-tested"; after K20 "TestFlight".
- **Tests & CI lane:** K02 "backend job: pgTAP + race + live suite + Deno"; K04 "contract recording starts"; every slice "contracts replayed on macOS".
- **HITL lane:** ticket 005 (local runtime, before manual passes); staging publishable key (K03/K19); OD-15 mail + support (K04 staging, K14, K15, K19); OD-16 staging plan (K19); TMDB key (K14); ticket 009 prototype review (before K08a); ticket 007 facets (improves K13); D39 Apple enrolment + APNs key (K16 revoke, K17 device, K18, K20).
- **Badges:** strongest on K04, K16 (AUTH + DELETE), K18 (AUTH), K03/K19 (ENV), K07/K08a/K09 (PRIVACY).

---

## 11. Numbers that matter

| Number | Value | Source |
|---|---|---|
| Tabs | 5 | D19 |
| Slices | 20 (core loop complete at K08b, the 9th) | 8.2 |
| Edge Functions | 3 | 2.5 |
| Tables | ~35 incl. taxonomy and private system tables | 4.2 |
| Weights R/T/L/I/F | 0.30 / 0.25 / 0.20 / 0.15 / 0.10 | `N-ALG` |
| Cold-start taste weight | 0.10 (R, L +0.075 each) when mean confidence < 0.3 | `N-ALG` |
| Show threshold | score ≥ 0.35 | `N-ALG`, `N-RS` |
| Min results before empty state | 3 | `N-ONB` C4 |
| Reasons per card | 2–4 | `N-ONB`, `N-ALG` |
| Max items per owner per set | 2 | `N-RS` |
| Feed sizes | 10 projects, 8 people, 5 preview | [design] |
| Taste cards | 12 shown, pick 3–5 (0 if skipped), ≥ 24 per realm | `N-ONB` O4 |
| Pairwise | 3 fixed (skippable) | `N-ONB`; follow-ups cut |
| Handle | 3–20 | AD |
| Password | ≥ 10 chars | `N-ONB`; repo `config.toml` |
| Requests | 5/day (< 7-day account), 20/day | `N-BF` |
| Reports | 10/day | `N-BF` |
| Request expiry | 14 days | `N-BF` |
| Re-request after decline | 90 days | [design] |
| Project expiry | 30 days, renewable | accepted OD-13 |
| Auto-hide | 3 qualifying reporters (eligible, verified, account ≥ 3 days) | accepted OD-6; [design] qualification |
| Report review | daily, 24 h target | D34 |
| Deleted user's message text | erased after 30 days | D42 |
| Report evidence | 1 year after closure (proposal); deleted users' message text per OD-20 | `N-DM`; OD-20 |
| Signed URL TTL | 10 minutes | [design] |
| Push retry | 1 m, 5 m, 30 m, 2 h; dead after 5 attempts; lease 2 min; drain every minute | [design] |
| Message overlap window on reconnect | 5 minutes | [design] |
| Idempotency window | 24 h (`op_results`) | [design] |
| Abandoned sign-up purge | 7 days without eligibility | [design] |
| Chat sends | 30/min | [design] |
| Message / request / bio / caption | 2000 / 500 / 280 / 140 chars | `R-BE` [design] |
| Uploads | avatar 1 MB (≤ 1024 px); user media 2 MB | `R-BE §5.1`, `N-ARCH` |
| Built-in email | 2/hour/project | `R-BE §4.2` |
| Realtime free plan | 200 connections, 100 msg/s | `R-BE §3.2` |
| Edge Function limits | 2 s CPU, 256 MB, 150 s wall (free) | `R-BE §2.1` |
| MusicBrainz / TMDB | 1 req/s per IP / ~40 req/s, ≤ 6-month cache | `R-IOS §6` |
| Latency budget | `recommend` < 400 ms p95 (unmeasured) | `N-ALG` |
| Quality bar | cold start < 2 s (iPhone 12); crash-free ≥ 99.5% before widening beta | `N-ARCH` |
| Existing tests | 21 `@Test` + 2 UI test methods + 10 pgTAP (declaration counts) | review X audit |
| TestFlight | 100 internal / 10,000 external; builds expire after 90 days | `R-IOS §8.1` |
| **Seed volumes (v0 model, C-33)** | 60 users (52 onboarded incl. 3 who skipped taste, 5 mid-onboarding, 1 suspended, 1 hidden by auto-hide, 1 in `deleting`); 25 projects (12 published, 5 draft, 3 closed-filled, 2 closed-by-owner, 2 past-expired, 1 past-completed); 30 requests across all statuses and kinds; 8 direct conversations incl. one closed by block and a new generation after unblock; ~100 messages incl. one from a deleted sender past 30 days (erased); 90 collab photos; 96 taste cards; ~250 favourites; 4 blocks; 6 reports (one subject auto-hidden) | [design] after `R-BE §6.2` |

**Cost (C-39).**

| Item | Cost | Source / status |
|---|---|---|
| Apple Developer Program | USD 99/year | `R-IOS §8.1`; deferred (D39) |
| Supabase staging | Free now; Pro later (OD-16) | Price **[unverified; not researched this round]** |
| Supabase production | Not used in v0 | D10 |
| SMTP provider + sending domain | **TBD** | OD-15 |
| TMDB, MusicBrainz | Free for non-commercial use; commercial licences before public launch | `R-IOS §6` |
| GitHub Actions macOS minutes | Billed at a higher rate than Linux on private repos **[unverified rate]** | — |
| Image moderation API | None (accepted OD-11) | — |

---

## Appendix A — Reconciliation log (v2)

v1 rows 1–36 stand except where updated below. Notion was read in full on 2026-10-25 ([[2026-10-25-notion-technical-extracts]]).

| # | Topic | Notion | v1 | Locked / review | v2 |
|---|---|---|---|---|---|
| 10 | City visibility | private in `profile_settings` | private, OD-4 open | **D41** public | `profiles.city_id` public |
| 10b | Availability, work mode | private | private | coordinator: keep owner-only | private; never in person reasons (OD-19) |
| 13 | Favourites | shared catalogue | per-profile | X-18 | per-profile + display and matching consents |
| 18 | Request duplicates | pending only | pending + declined | C-25, X-09 | pending per pair+project (either direction) + RPC checks (accepted, open Crew conversation, 90-day decline) |
| 21 | Conversations | per accepted request | unique per pair | X-11, C-06 | one open per pair; generations after block |
| 24 | Deleted sender's messages | delete 30 days after deletion | kept (AD) | **D42** | kept as "Deleted user", text erased after 30 days |
| 35 | Staging bundle ID | — | OD-5 | **D43** | `club.kizuki.ios` |
| 37 | Accepted connections | — | "Matches" (OD-14) | **D40, D44** | "Crew" |
| 38 | Onboarding goal | O3 three intents | three-option screen | FIG-V: two options | two options + Start/Join follow-up [design] |
| 39 | Request form | idea_text, message | role + message | FIG-V `1480:4806` | role, time commitment, notes |
| 40 | Suki chooser | — | New project / Post a collab | FIG-V | Get discovered / Create a project / Post a collab |
| 41 | `send-request`, `respond-request` as Edge Functions | Edge Functions | SQL RPCs | X-01/02 | SQL RPCs with locks (row locks need the transaction) |
| 42 | `discoverable` | in profiles SELECT policy | same | C-08 | Stage 0 only |
| 43 | Reports | reporter reads own | reporter reads row incl. snapshot | X-03 | reporter-readable row; evidence private |
| 44 | Serendipity | O8 + mix | mix kept | C-18 | cut from v0; stored default |
| 45 | Logging | `recommendation_sets/items` required | kept | C-18 | cut from v0 |
| 46 | Role adjacency | adjacent role 0.4 | same realm 0.4 | C-38 | same realm 0.4, logged deviation |
| 47 | Push trigger | DB webhook | DB webhook | C-03, X-06, X-08 | outbox + Vault-configured `pg_net` + cron drain + server secret |
| 48 | Apple revocation | — | manual fallback | X-13 | exchange + revoke; fallback only without a code |

---
title: Kizuki v0 architecture concept v2.1 (amendment to v2)
created: 2026-10-25
version: 2.1
tags: [project/kizuki, architecture-round, concept, amendment]
status: final-for-round-1
amends: 2026-10-25-architecture-concept-v2
---

# Kizuki v0 architecture concept v2.1 (amendment)

Related: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-concept-v2-changelog]], [[2026-10-25-concept-v2-verification-codex]], [[2026-10-25-prototype-report]], [[2026-10-24-architecture-round-1-interview]], [[2026-10-25-wayfinder-map]], [[playbook]]

## 0. Scope and how to read this

- **This is an amendment, not a rewrite.** v2 stands except where a section below replaces or extends it. Where this file and v2 disagree, this file wins.
- It resolves the three round-2 blockers concretely: **F02 / VF01** Crew connection generations (section 1), **F04 / VF02** message moderation without raw-body leaks (section 2), **F05 / VF03** the build dependency graph, rebased onto the in-app prototype, with a live Swift run required for the core loop (section 3).
- It folds in decisions D46–D57 (section 4) and closes the cheap round-2 findings (section 5). Everything else from round 2 is a follow-up ticket VF04–VF13 on the map; the round-2 changelog appendix maps every F-finding.
- Round 2 was the last review round (playbook rule 4). Nothing here is re-reviewed; the build tickets and their cross-model reviews carry the residual risk.
- Citations as in v2. `V2 §x` = v2 section. `PR` = [[2026-10-25-prototype-report]]. `VR` = [[2026-10-25-concept-v2-verification-codex]].

---

## 1. Crew connections and generations (resolves F02, F12; VF01)

### 1.1 Plain language

When someone accepts your request, the two of you become **Crew** and a chat opens. That bond is a **connection**. It can end three ways: one of you removes the other from Crew, one of you blocks the other, or an account is deleted. Old requests stay in the history exactly as they were. A new request can start a new connection later, with a new chat. Removing someone is quieter than blocking: they can still read the old chat, but they cannot message you or send you a new request for 30 days.

### 1.2 Model

New table **`crew_connections`** (replaces "accepted request = permanent bond"):

| Column | Notes |
|---|---|
| `id` uuid | |
| `pair_low`, `pair_high` | FK `profiles` **on delete set null**; CHECK `pair_low < pair_high` while both non-null |
| `status` | `active`, `ended` |
| `started_at`, `origin_request_id` | origin request FK `requests` on delete set null |
| `ended_at`, `ended_reason` | `removed`, `blocked`, `account_deleted`, `suspended` |
| `ended_by` | profile that removed/blocked; set null on deletion |

- **One active connection per pair**: partial unique `(pair_low, pair_high) where status = 'active'`.
- **`conversations.connection_id`** unique FK (replaces the v2 pair partial index as the generation key). Each connection has exactly one conversation; a conversation is open iff its connection is `active`. `conversations.closed_at` mirrors `ended_at`.
- **Crew** (Suki › Crew) = the caller's `active` connections. Accepted requests are history only and never change after they are final (V2 §4.4).
- RLS: participants of the connection read it; writes only through RPCs.

### 1.3 Requests vs connections (D52)

| UI label (D52) | `kind` | Project | Creates / reuses |
|---|---|---|---|
| **Wish to Collab** (from a person's profile) | `collab_person` | optional; message required when none | connection only |
| **Join project** (from a project) | `join_project` | required + seat | membership + connection |
| **Invite** (owner, from My Projects) | `invite_to_project` | required + seat | membership + connection |

**Accept** (`respond_request`, V2 §4.5 contract plus): if the pair has an `active` connection, reuse it and its conversation; otherwise create a new connection and a new conversation. It returns `{conversation_id, connection_id}`; the app **navigates straight to that chat** from wherever the accept happened (request detail, push action) (D53).

### 1.4 Duplicate guard, scoped to the active connection

Replaces V2 §4.4 "Duplicates" (the permanent accepted pair+project guard is removed):

1. **Pending:** one pending request per `(pair_low, pair_high, project_id)` `nulls not distinct`, either direction (unchanged).
2. **Wish to Collab:** refused with `already_crew` while the pair has an `active` connection. Allowed whenever there is none, regardless of any earlier accepted request.
3. **Join / Invite:** refused with `already_member` while the seat filler is a current `project_members` row of that project. Past accepted requests for the project do not block.
4. **Decline window:** 90 days per sender→recipient→project_key (unchanged).
5. **Removal cooldown:** the person who was removed (`ended_reason = removed`, `ended_by = X`) cannot send any request to X for 30 days → `cooldown(retry_after)` [design]. X can send at any time. Blocks have no cooldown after unblock: the blocker chose to unblock.

### 1.5 Remove from Crew (D54)

`remove_from_crew(other_profile_id, op_id)`; locks per V2 §4.5 order (profiles → pair advisory → connection row → affected project rows ascending → seat rows → request rows → conversation).

Effects in one transaction:
- Connection → `ended`, `ended_reason = removed`, `ended_by = me`; conversation closed.
- Pending requests between the pair, both directions → `withdrawn`.
- `project_members` between the pair, both directions, removed; seats reopened on still-published projects (same rule as block, V2 §2.11) [design: a member you cannot message cannot coordinate].
- Queued pushes between the pair are skipped at delivery (delivery checks an active connection for message kinds).
- **Never inserts a block.**
- Chat history after removal: **read-only and visible to both**, labelled "No longer in your Crew". Block-ended conversations stay hidden from both (V2 §2.6). Deletion-ended ones are read-only with "Deleted user".
- Idempotent: same `op_id` → stored result; no active connection → success with `already_ended`.

Block (`block_user`) now ends the active connection with `ended_reason = blocked`. Account deletion's freeze ends all of the user's connections with `account_deleted`. Reviewer suspension ends them with `suspended`.

### 1.6 Exact test sequences (pgTAP + race harness + live Swift)

| # | Sequence | Expected |
|---|---|---|
| T1 | A Wish→B (no project); B accepts; A blocks B; A unblocks; A Wish→B; B accepts | conn1 ended(blocked), conv1 hidden from both; conn2 active with new conv2; messages to conv1 refused, to conv2 delivered; request 1 still `accepted` |
| T2 | T1 but after unblock **B** sends Wish→A | same outcome, reversed sender |
| T3 | A, B Crew; A removes B | conn ended(removed, by A); conv read-only for both; **no `blocks` row**; B Wish→A → `cooldown`; A Wish→B → allowed; accept → conn2 + conv2 |
| T4 | A joined B's project P (member); B removes A | A's membership gone, seat reopened (P published); after 30 days A Join P → allowed; accept → member again + new connection |
| T5 | A, B Crew; B invites A to P2 | allowed; accept reuses conn1/conv1, adds membership; no second conversation |
| T6 | A, B Crew; A Wish→B | `already_crew` |
| T7 | `remove_from_crew` twice, same `op_id` | identical result; with a new `op_id` → `already_ended` |
| T8 | Races (two connections): remove vs `send_message`; remove vs accept of a pending project request; A removes B while B removes A; remove vs block | send either commits before removal or fails `stale_state`; accept either commits then removal ends it, or removal withdraws then accept fails `stale_state`; exactly one removal wins, the other `already_ended`; block after removal ends nothing new and still hides conv |
| T9 | Any of T1–T8 | every final request row unchanged after reaching its final state |
| T10 | A, B Crew; B deletes account | conn ended(account_deleted); A's Crew no longer lists B; conv read-only showing "Deleted user"; pair key B → null |
| T11 | Live Swift run (local stack): B accepts in the app | app lands in the chat screen of the returned conversation (D53) |

Owner: slice B07 (requests + Crew) for T1–T9 and T11. B07 therefore ships a **minimal `block_user` / `unblock_user`** (block row, end connection, hide conversation, withdraw pending requests); B10 (safety) extends block with memberships, likes, reports and moderation and re-runs T1, T2 and T8. B17 (deletion) runs T10. Time-dependent steps (30-day cooldown) use a test clock: RPCs read `private.now()`, which returns `now()` except in test sessions where pgTAP sets it.

---

## 2. Message moderation without raw-body leaks (resolves F04; VF02)

### 2.1 Plain language

A chat message is stored in two parts: a small **envelope** (who, when, which chat, hidden or not) and the **text** itself in a separate table. The live feed only ever carries envelopes. The app fetches text separately, and the database refuses to hand out the text of a hidden or erased message to anyone but its sender. So hiding a message cannot leak through any back door, and the app replaces the text with a placeholder.

### 2.2 Design: envelope/content split (chosen)

Replaces the `messages` row in V2 §4.2 and the send path in V2 §2.6.

| Table | Columns | Realtime publication | RLS (SELECT) |
|---|---|---|---|
| `messages` (envelope) | id, seq, conversation_id, sender_id, client_id, created_at, hidden_at, sender_deleted_at, erased_at | **yes** (`supabase_realtime`) | `private.is_participant(conversation_id)` + `caller_ok()` + block policy (block-ended conversations hidden). **No body column exists.** |
| `message_bodies` (content) | message_id (PK, FK `messages` on delete cascade), body text 1–2000 | **no** | caller is a participant **and** (`envelope.hidden_at is null` **or** caller is the sender) **and** `envelope.erased_at is null`; implemented with a definer helper `private.can_read_message_body(message_id)` returning a boolean |

- **Writes:** clients have no INSERT/UPDATE/DELETE grant on either table. `send_message(conversation_id, client_id, body)` (definer, V2 §2.3 rules) locks the conversation `FOR SHARE`, checks the connection is `active` (section 1), both participants live and not blocked, the text filter and rate limit, then inserts the envelope and the body in one transaction. Replays by `(sender_id, client_id)` return the existing envelope.
- **Moderation:** auto-hide or a reviewer sets `messages.hidden_at`. That is an UPDATE on the envelope, so subscribers receive an UPDATE event carrying only envelope columns. Recipients can no longer read the body row; the sender still can and sees a "hidden" label.
- **Erasure (D42, D49):** the erase job deletes the `message_bodies` row and sets `erased_at`. D49: if an open report references the message, the body row is kept until that report closes, then erased by the same job.
- **Report evidence** is captured from the reporter's visible projection at report time (V2 §2.11), so it is unaffected by later hiding.

**Rejected alternative:** a projection view or RPC that returns `body` or a placeholder. Postgres Changes cannot stream through a view or an RPC, so live delivery would need a second channel or Broadcast. That reopens the authorization drift v2 avoided (V2 §2.6).

### 2.3 Client transport (`ChatTransport`)

1. Subscribe to `postgresChange(AnyAction.self, table: "messages", filter: conversation_id=eq.<id>)`. Events carry envelopes only.
2. For each new or changed envelope with `hidden_at` and `erased_at` both null: fetch the text with `select message_id, body from message_bodies where message_id in (…)`, batched up to 50 per call.
3. Envelope with `hidden_at` set and the caller is not the sender: **purge the cached body** for that id and render the "message hidden" placeholder. `erased_at` set: purge and render "Message removed".
4. Reconnect and foreground reconciliation fetch envelopes (V2 §2.6, with the gap-recovery change owned by VF10) and re-apply step 3 to the cache before display.
5. Body cache lives in the user's `SessionScope` and is purged on sign-out or account switch (V2 §2.2).

### 2.4 Tests (slice B08; B10 re-runs with reports)

| # | Test | Expected |
|---|---|---|
| M1 | Schema assertion | `messages` has no `body` column; `message_bodies` is **not** in `pg_publication_tables` for `supabase_realtime` |
| M2 | Recipient REST `select * from message_bodies where message_id = <hidden>`; also `select body` via an embedded `messages(message_bodies(body))` select | zero rows / null embed |
| M3 | Sender reads own hidden message | body returned, `hidden_at` set |
| M4 | Non-participant and blocked participant | no envelope, no body |
| M5 | Live Realtime (two clients, local stack): send, then hide | INSERT payload keys ⊆ envelope columns; UPDATE arrives; recipient client cache no longer contains the text (Swift unit test on `ChatTransport` with recorded events, plus the live Swift run) |
| M6 | Erasure job at day 30 (test clock) | body row gone, `erased_at` set, client shows "Message removed" |
| M7 | D49: deleted sender, open report on the message | body kept until the report is closed, then erased by the next run |
| M8 | Direct INSERT into `messages` or `message_bodies` as `authenticated` | permission denied |
| M9 | Unhide by reviewer | recipient can read the body again on next fetch |
| M10 | `send_message` racing `remove_from_crew` and `block_user` | per section 1 T8 |

---

## 3. Build dependency graph, rebased onto the prototype (resolves F05, F16, F17; VF03; revalidates F09)

### 3.1 Plain language

The app's screens already exist as a clickable prototype on invented data. The build now swaps that invented data for the real backend, one slice at a time. Every slice adds its own database tables before anything uses them. Each slice must pass its tests starting from an empty local database that has only the migrations up to that slice. The core-loop slices must also pass a real run of the iPhone app against that local database.

### 3.2 Baseline: the prototype now in the app (PR)

- Targets in `KizukiKit`: Core (models `Person`, `Project`, `CollabRequest`, `Conversation`, `CollabPhoto`, `OwnProfile`, `Recommendation`; six repository protocols + `Dependencies`; `AppRoute`/`AppSheet`/`AppTab`; `AppRouter`; `AppStore`), DesignSystem (tokens, bundled fonts, components, `KizukiIcons` with five tab icons), TestSupport (`FixtureData`, `FixtureBackend`, all `#if DEBUG`), and eight features: **Onboarding, Home, Search, Suki, MyProjects, Profile, Chat, Settings**, plus foundation Infrastructure and FoundationFeature (PR "Module layout"; VR F16).
- App target: `PrototypeRoot` (system `TabView`, one stack per tab, sheet resolution, `GalleryScreen` launch router with 39 screen ids); Debug defaults to fixtures, `-live` shows the foundation root.
- Tests: 27 Swift `@Test` and 6 UI test methods (VR F16; PR "Verification").
- **v2.1 adopts the prototype's module names** (Onboarding replaces v2's Entry; Chat is its own feature; Settings replaces Account). `KizukiPlatform` and `KizukiEmbeds` are still to be created. `AppStore` stays as the read model and may split per feature once live data arrives (PR "Deviations from concept v2").
- **Composition rule for every slice:** a `Supabase<Name>Repository` in Infrastructure implements an existing Core protocol (or an extended one). The App target chooses `Live` or `Fixture` per launch argument. Fixture tests stay green. A fixture expectation that contradicts a locked decision is rewritten in the same slice (VR "Repository checks": the old block/unblock fixture expectation).

### 3.3 Dependency rules (replace V2 §8.1 bullet 3)

1. **Schema before consumer.** A slice may call only tables, functions and RPCs created by itself or an earlier slice.
2. **Versioned intermediate contracts.** A shared function that later slices extend is created with a minimal, tested body and replaced (`create or replace`) by the slice that owns the extension. Each version has its own pgTAP file. The function name and signature never change.

| Function / table | v1 (slice) | Later versions |
|---|---|---|
| `blocks` table, `private.is_blocked` | B02: table + helper (always correct; empty until rows exist) | B07 minimal block RPC; B10 full side effects |
| `notification_outbox` table | B02: table, no writers | B07/B08 triggers enqueue; B18 sender drains the backlog (rows older than 24 h are skipped) |
| `private.can_view_profile` | B02: self, or eligible + onboarded + active + not hidden | B07 adds the relationship branch (connections, requests, memberships) with the subject-liveness predicate first (F19); B10 adds moderation states |
| `private.freeze_account` (deletion step 1) | B04: profile, settings, legal rows | extended by B06 (projects, memberships), B07 (requests, connections, conversations), B08 (messages: `sender_deleted_at`), B11 (stop uploads), B17 (complete + Storage + Apple). Each extending slice adds a deletion test for its own tables |
| `private.on_project_left_published` | B06: no-op hook called by close/complete/expire | B07: expire the project's pending requests |
| `private.recompute_taste` | B07: sets `taste_dirty_at` only | B14: real recompute |
| `recommend` taste component | B09: T = 0.5 neutral, band null (V2 cold start) | B14 taste; B15 favourites |
| `private.is_participant` | B07 (with conversations) | — |

3. **Prefix proof.** Migration files carry the slice ID (`2026xxxxxxxxxx_b07_requests_crew.sql`). `scripts/test-prefix.sh B07` copies migrations up to the last B07 file into a temporary Supabase project dir, runs `supabase db reset` on the local stack, then runs `supabase/tests/b01…b07`. CI runs the prefix check for every slice up to the newest on each PR. A `db reset --version` flag could replace the copy step **[unverified in CLI 2.122.0]**.
4. **Deletion is never "later".** From B04 on, every slice that adds user-linked rows extends `freeze_account` and the FK matrix (V2 §4.3) in the same PR.

### 3.4 Slices (21; replaces V2 §8.2)

`Live run` = a real Swift app run on the simulator against the local Supabase stack (3.5). Ticket numbers are on the map.

| ID | Ticket | Slice | Adds schema / code | Proof (from an empty DB with migrations ≤ this slice) |
|---|---|---|---|---|
| B01 | 012 | **Live composition seam** | `Dependencies.live(...)` vs `.fixture`; `AppSession.refreshProfile`, root phases, `SessionScope` (V2 §2.2); prototype root kept behind `-fixtures`; Swift contract-replay test harness | Unit tests; fixture UI tests stay green; live run reaches the signed-out entry against the local stack |
| B02 | 013 | **Backend backbone + test harness** | Enums, taxonomies, `private` schema, `caller_ok`, `is_blocked`, `can_view_profile` v1, grants; profiles/settings extensions (public city **and availability**, D51; private work mode); `legal_acceptances`; `blocked_terms`; `op_results` with atomic reservation (VF04); `blocks` and `notification_outbox` tables; environment marker table; `[db.seed]`, `[storage]`, `[edge_runtime]` on; seed generator + local loader; CI `backend` job (pgTAP, race harness, Deno runner, prefix check); `scripts/test-prefix.sh` | pgTAP for helpers, grants and recursion; one sample race test; prefix check B02; local stack starts (closes ticket 005) |
| B03 | 014 | **Environment pinning + bootstrap** | Exact staging allowlist; runtime `.production` refusal in `AppConfiguration`; validator; `Staging.xcconfig` (D43); `kz-remote.sh` with first-deploy bootstrap (VF08) | Swift + Python negatives (unapproved host, production, link state, wrong pooler, empty production) with no remote writes |
| B04 | 015 | **Email auth + eligibility + deletion v1** | Sign-up, verify code, sign-in, sign-out, recovery by code; Terms/18+ gate first; `decline_eligibility`, `begin_account_deletion`, `freeze_account` v1, auth-only `delete-account`; `purge-abandoned-signups`; email templates | pgTAP gate; live suite; **live run**: sign-up → Mailpit code → eligibility → recovery; under-18 deletes the account |
| B05 | 016 | **Onboarding live** | `save_onboarding_step`, `set_handle`, `missing_fields`, `complete_onboarding`; location purpose strings; wires `KizukiOnboardingFeature` | pgTAP readiness levels; **live run**: three paths, resume after relaunch, permission denial |
| B06 | 017 | **Projects + My Projects** | `projects`, `project_roles`, `project_members`, project RPCs and invariants, expiry job, `on_project_left_published` v1, onboarding Start draft, `freeze_account` + projects | pgTAP state machine and locked fields; **live run**: create → publish → expire (test clock) → renew; My Projects segments |
| B07 | 018 | **Requests + Crew** (section 1) | `requests`, `request_decline_reasons`, `crew_connections`, `conversations`, `conversation_participants`, send/respond/withdraw/`remove_from_crew`, minimal `block_user`/`unblock_user`, outbox enqueue triggers, cooldown, `can_view_profile` v2, `on_project_left_published` v2, `freeze_account` + requests/connections; Wish to Collab / Join project copy (D52); accept navigates to the conversation route (D53) | Section 1 T1–T9; race suite (accept/accept, accept/close, accept/remove, send/withdraw); **live run**: Join project → accept → app lands in chat (T11), Remove from Crew |
| B08 | 019 | **Chat** (section 2) | `messages` envelope, `message_bodies`, `send_message`, Realtime publication, `ChatTransport`, Inbox, thread, unread, mute; `freeze_account` + messages | M1–M10; gap-recovery tests from VF10; **live run**: two users (app + scripted second user) exchange messages, hide, reconnect |
| B09 | 020 | **`recommend` + Home** | Weights, Stage 0 incl. request/connection exclusions, Stage 2 with neutral taste, privacy-safe reasons (section 5), feedback RPCs, Home, see-more lists, C4 preview | Golden fixtures (V2 §2.10 + section 5 additions); reason allowlist test; **live run**: Home shows seeded results, Join project from a Home card. **Core loop complete** |
| B10 | 021 | **Safety** | Full block side effects, reports split, moderation states, auto-hide, Report on every live surface so far, `can_view_profile` v3 (VF05) | Visibility matrix both directions; T1, T2, T8 re-run; live block/report pass |
| B11 | 022 | **Storage, avatars, covers** | Buckets and policies, path CHECKs, renditions, scoped cache, `freeze_account` + uploads stopped | Storage pgTAP; live upload/sign/block/deleting tests |
| B12 | 023 | **Search media + Post a collab** (D55) | `collab_posts` (photo or short video, section 4.5), video pipeline, grid, chips, post viewer; no people results | Live post photo + video → grid → auto-hide; video limits enforced server-side |
| B13 | 024 | **Profile + links/embeds + Get discovered** | Own/other profile, edit, public availability display, `portfolio_sources`, `KizukiEmbeds`, Get discovered card (section 4.7) | Parser tests; consent visibility; provider smoke on device (when available) |
| B14 | 025 | **Taste cards + pairwise** | Taste tables, placeholder art, `submit_taste`, `recompute_taste` v2, taste in `recommend` | Maths vs hand-computed values; replay; VF10 band edge cases |
| B15 | 026 | **Favourites** | `tmdb-proxy`, MusicBrainz client, favourites + both consents (picker and Settings, D48) | Deno tests; rarity population; consent-off |
| B16 | 027 | **Settings, legal, support** | Settings pages, notification preferences, blocked list, legal pages, support, sign-out with token unlink | UI; live preference persistence |
| B17 | 028 | **Full deletion + retention** | Storage purge with quiescence (VF07), refresh-token revocation, job-secret path, resume job, D42/D49 erasure, Apple revoke credential handling (VF07), complete FK matrix | Populated-graph deletion; paused-upload test; crash points; T10 |
| B18 | 029 | **Push** | Per-device deliveries, fenced leases (VF06), Vault fast path + cron drain, `send-push`, token register/unregister, tap routing, Push capability | Deno + pgTAP per VF06; device after D39 |
| B19 | 030 | **Sign in with Apple** | Nonce flow, entitlement, D47 link disclosure + Undo, authorization code for deletion | Unit; device after D39 |
| B20 | 031 | **Staging deploy + seed + smoke** | Staging loader, marker bootstrap via gateway, migrations/functions/secrets/auth config, full smoke checklist | Every flow on a simulator against staging. **Apple items (B19, device push) are a deferred checklist if D39 is still open** (VF03) |
| B21 | 032 | **Release plumbing + TestFlight** | Privacy manifest, export compliance, 18+ rating, App Store Connect, review notes, demo account; Pro plan before external testers (D46) | Archive validates; internal TestFlight install |

**Count: 21 slices** (F17). Critical path: B01–B03 → B04 → B05 → B06 → B07 → B08 → B09 → B10 → B11 → B17 → B20 → B21. After B07, B08 and B09 can run as parallel lanes (separate migrations and feature modules). After B11, B12, B13 and B14 can run in parallel.

### 3.5 Test strategy, revalidated (F09; VF09 owns the pipeline)

- **Docker now works locally** (OrbStack, engine 29.8.2; VR "Repository checks"). The local stack is the primary live target from B02 on. Ticket 005 closes when `scripts/supabase-local.sh start` succeeds (B02 exit).
- **Required for B04–B09: a live Swift run.** A `KizukiLiveUITests` target (or launch-argument mode of the existing UI tests) runs the real app on a simulator with `-live` against `http://127.0.0.1:54321` (the simulator shares the host network). It is seeded by the local loader. A Deno/supabase-js helper script plays the second user (accepts, replies) between UI steps. Artifacts: the `.xcresult`, screenshots and a short run note at `docs/lanes/<date>-<slice>-live-run.md`. The builder runs it; the cross-model reviewer re-runs it before merge.
- **CI** cannot host the stack on `macos-15` **[unverified: hosted macOS arm64 runners lack nested virtualization]**. CI runs pgTAP, race, live API (Deno) and prefix checks on Linux, and fixture UI tests plus contract replay on macOS. The live Swift run is a local merge gate, not a CI job.
- **Contract recordings, enforceable:** `scripts/contracts/record.sh` (owner: the live API suite) records each repository call against the local stack, normalises it (ids → stable placeholders, timestamps → markers, sorted keys) and writes `ios/Tests/Contracts/*.json`. The files are committed. The Linux CI job re-records and **fails on any normalised diff**; the macOS job replays the committed files. Transfer between jobs happens through the repository, not artifacts.
- **Deferred live cases** (staging, devices, provider playback, Apple, APNs) are blocking checklist items of B20/B21, not slice proof.

---

## 4. Decisions D46–D57 folded in

### 4.1 Settled ODs (D46–D50; resolves F15)

| Decision | v2 change |
|---|---|
| D46 Staging on Free while building, Pro before external testers | OD-16 closed. B21 exit requires Pro. Pausing risk accepted until then |
| D47 Accept automatic identity linking, tell the user immediately with Undo | OD-17 closed. B19 implements disclosure + `unlinkIdentity` Undo; the "spike" becomes a test of the disclosure path |
| D48 Favourites in matching on by default, toggle in Settings | OD-18 closed. Toggle in Settings › Privacy & Safety **and** on the picker (V2 §2.13); B15 + B16 |
| D49 Reported messages of a deleted user kept until the open report closes, then erased | OD-20 closed. **Replaces V2 §4.7's "30 days after closure".** `reports.closed_at` is set when status becomes `actioned` or `dismissed`. The erase job deletes `message_bodies` rows for messages with `sender_deleted_at` older than 30 days and no open report, including those whose last open report just closed. Legal confirmation before public launch is a B21 gate |
| D50 | Superseded by D51 |

### 4.2 Availability is public; work mode stays private (D51; resolves F10)

- `availability_band` moves from `profile_settings` to **`profiles`** (public, column-level UPDATE by owner). Shown on every visible profile (own and other), on person cards, and editable in onboarding and profile edit. `work_mode` stays in `profile_settings` (owner-only).
- Reasons: `same_window` is now allowed for **people** too (public field). Work-mode-derived reasons stay forbidden for people (section 5.1).
- ERD (V2 §10.4): `profiles` gains `availability_band`; `profile_settings` loses it.
- Tests: raw REST select of another user's `profiles.availability_band` succeeds; `profile_settings.work_mode` of another user returns no row.

### 4.3 "Wish to Collab" vs "Join project" (D52; resolves F11 copy)

Section 1.3. From a person's profile the CTA is **Wish to Collab** (`collab_person`, project optional). From a project it is **Join project** (`join_project`). Owner invites stay "Invite". The prototype's "Ask to collaborate" copy is renamed in B07.

### 4.4 Accept opens the chat (D53; resolves F11 navigation)

`respond_request(accept)` returns `conversation_id`. The app calls `router.open(.conversation(id))` on the Home tab stack (where Inbox lives, V2 §2.2) immediately, for every kind including invites and Wish to Collab. For a reused connection it opens the existing chat. Live-run assertion T11.

### 4.5 Search is photos or short videos only (D55; resolves F13 partly)

- **No people results** in Search: V2 §5.6's people row is removed; handles are found only via Home and profiles.
- **v0 needs video storage.** D55 names short videos as Search content, so video is a v0 requirement, not a deferral.
- Content type `collab_photos` becomes **`collab_posts`** with `media_kind` (`photo`, `video`), `poster_path`, `duration_ms`, `width`, `height`, caption, tags, `hidden_at`.
- **Limits [design]:** ≤ 15 s; exported on device to MP4 (H.264 video, AAC audio) at 720p with `AVAssetExportSession`; ≤ 15 MB; one media item per post. A poster JPEG is generated on device and uploaded as the thumbnail. HEIC and HEVC inputs are converted on device.
- **Storage:** a second private bucket **`user-video`** (allowed MIME `video/mp4`, 15 MB limit). Bucket limits are per bucket, so it cannot share `user-media`'s 2 MB cap. Path `<uid>/post/<post_id>/video.mp4`; same policies, CHECKs, signing TTL and deletion purge as `user-media` (V2 §2.7).
- **Server-side enforcement:** MIME and size via bucket settings; `duration_ms ≤ 15000` CHECK on the row. Actual duration cannot be verified without server processing; the size cap bounds abuse (accepted risk).
- **Playback:** grid shows posters only. The post viewer plays muted and looped with `AVPlayer` from a 10-minute signed URL; tap to unmute. No autoplay with sound (Notion MVP exclusion).
- **Reporting** as for photos; "intellectual property" covers music in videos.
- **Open questions** (ticket VF12): maximum duration (15 s proposed); allow audio or strip it on upload; muted autoplay in the viewer vs tap-to-play; Free-plan egress and storage for video **[unverified limits]**; HDR handling; whether a post may hold several items; video moderation burden under OD-11.

### 4.6 Floating tab bar with Kizuki icons (D56; resolves F14)

- System `TabView` (D32), which renders as the floating glass bar on iOS 26 and the classic bar on iOS 17–18; no custom bar.
- Icons already in the prototype: asset catalog `KizukiIcons.xcassets`, template rendering, tinted by the system selection state. Source and mapping in `docs/design/icons/README.md`: `TabHome` polaroid-star, `TabSearch` magnifier-star, `TabSuki` eye disc, `TabMyProjects` folder-star, `TabProfile` bust-starburst. App icon light/dark/tinted in `AppIcon.appiconset`; wordmark and K mark from Figma `3po5ynomzdPNe2mcO7IKRw` `614:262`, `614:372`.
- **Acceptance (B01 regression check, VF12 for asset swap):**
  - VoiceOver labels Home, Search, Suki, My Projects, Profile.
  - Selected and unselected states legible in screenshots on iOS 26 and on an iOS 17 simulator.
  - Icons at ~28 pt with no clipping.
  - App icon present in all three appearances.
- **Known gap:** the tab icons are traced from a raster sheet (icons README). Replace them with the designer's vector originals when exported (VF12).

### 4.7 "Get discovered" placement and rationale (D57; resolves F26)

- **Placement:**
  - Primary: a **"Get discovered" card at the top of your own Profile** while your profile is incomplete. Its checklist covers availability, roles, bio, photo, a link, favourites and a first collab post. It opens Edit profile at the first missing item.
  - Secondary: one dismissible Home card shown once after onboarding if the checklist is under half complete.
  - **Not** in the Suki create chooser, which keeps the prototype's two creation actions (Create a project, Post a collab).
- **Why:**
  - Getting discovered means improving your own profile, and people look for that on their own profile.
  - The Suki chooser is about making new things; mixing an edit action into it made the Figma chooser ambiguous (FIG-V correction 2).
  - The prototype already routes it to Profile › Edit (PR open question 8).
  - The checklist reuses the readiness fields (V2 §4.8), so the same data drives the nudge and the missing-fields sheet.
- Supersedes V2 §5.4's "Get discovered" chooser entry and the three-option chooser in V2 §9 (Suki 6–7).

### 4.8 Remove from Crew (D54)

Section 1.5.

---

## 5. Other round-2 findings closed here

### 5.1 Reason allowlist per target type (resolves F01; with D51)

Replaces V2 §2.10's reason table "Applies to" column. **People** reasons may use only: `complementary_role`, `similar_taste` (gated), `shared_favourite` (display + matching consent), `same_window` (availability is public, D51), `same_city` (public city), `beyond_your_city` (new, generic: "Beyond your city"; no work-mode claim), `stretch_pick`. **Projects** may additionally use `needs_your_role`, `same_project_type`, `works_remotely`, `remote_fallback`; all of these come from the project's own public fields. A pgTAP test asserts every person-candidate reason code ∈ the people allowlist, and that no reason params contain `work_mode`, `compensation_preference`, `preferred_project_type_ids` or `primary_intent` values (VF11 owns the test file).

### 5.2 Band edge cases (resolves F24 at the rule level; fixtures in VF10)

- V2 §0 item 7 said cold-start items get the "adjacent band". The operative rule (V2 §2.10) is **band null**; this amendment corrects the summary.
- Banding requires a non-zero facet vector on both sides **after** bridging. Favourites-only users, and cross-realm pairs with no shared-family facets, have no raw cosine, so their band is null. They are admitted by Stage 0 + threshold, exactly like cold start. Favourites still contribute to T.
- VF10 adds hand-computed goldens: favourites-only viewer, disjoint bridge, one-sided taste.

### 5.3 Counts and baseline (F16, F17)

21 slices (section 3.4). The prototype is the baseline (section 3.2). V2 §11 "Slices" and "Existing tests" are superseded: 27 `@Test` + 6 UI test methods at inspection.

### 5.4 Not closed here (tickets)

F03, F25 → VF04 · F18, F19, F20 → VF05 · F06 → VF06 · F07, F21, F22 → VF07 · F08 → VF08 · F09 pipeline details → VF09 · F23, F24 fixtures → VF10 · F01, F10 tests → VF11 · F11–F14, F26 implementation checks → VF12 · F15 release gates → VF13. Each VF ticket gates the slices listed in its `blocked_by` relation on the map.

---

## 6. Diagram spec deltas (apply to V2 §10)

- **10.1 System overview:** Storage node lists `user-video`. Realtime node reads "message envelopes only". New table node `message_bodies` with no Realtime edge.
- **10.2 Main flow:** step 1 label "Join project"; add the alt frame "Wish to Collab (no project)". Step 6 note adds "create or reuse Crew connection". New step after 6: "Ben's app opens the chat immediately (D53)". New alt frame "Remove from Crew: chat read-only, 30-day cooldown for the removed person, no block".
- **10.3 State machines:** add a fourth panel **Crew connection**:
  - Active → Ended, labelled "removed / blocked / account deleted / suspended".
  - Ended is final. "A new accepted request creates a new connection and chat".
  - Note: "removed: history read-only; blocked: history hidden".
- **10.4 ER:**
  - New entities `crew_connections` (pair, status, ended_reason, ended_by) and `message_bodies` (badge "never in Realtime").
  - `conversations.connection_id` 1–1 `crew_connections`.
  - `collab_photos` → `collab_posts` (media_kind).
  - `profiles.availability_band` public.
- **10.5 Roadmap:**
  - Slice cards B01–B21, ticket numbers 012–032, phases A Foundations (B01–B03), B Core loop (B04–B09), C Safety and content (B10–B16), D Account and platform (B17–B19), E Ship (B20–B21).
  - Follow-up cards VF04–VF13 (tickets 033–042) attached to the slices they gate.
  - A "live Swift run" badge on B04–B09.

---

## 7. What remains and what I am least sure of

**Unresolved blockers:** none in the concept. F02, F04 and F05 have concrete designs and test lists here. Their proof is in tickets 018 (B07), 019 (B08) and every slice's prefix check.

**Least sure:**
1. Whether a 30-day removal cooldown is the right default; it is a product call made here [design].
2. Short video in v0 (D55): limits, audio rights and Free-plan egress are unverified (VF12).
3. Whether the prefix check can run from a temporary migration copy as cleanly as described, and how long 21 prefix runs take in CI.
4. Whether the live Swift run with a scripted second user stays reliable enough to be a merge gate (Realtime timing).
5. Scope: still 21 slices plus 10 follow-up tickets.

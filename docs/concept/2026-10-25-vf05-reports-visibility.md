---
title: VF05 Report privileges, subject liveness and reporter hides
created: 2026-10-25
tags: [project/kizuki, architecture-round, design, safety, privacy]
status: final-for-build
resolves: [F18, F19, F20]
ticket: 034
amends: 2026-10-25-architecture-concept-v2.1
---

# VF05 Report privileges, subject liveness and reporter hides

Related: [[2026-10-25-architecture-concept-v2.1]], [[034-vf05-reports-visibility]], [[2026-10-25-concept-v2-verification-codex]]

See also: [[2026-10-25-architecture-concept-v2]], [[2026-10-24-architecture-round-1-interview]], [[2026-10-25-wayfinder-map]], [[033-vf04-concurrency-readiness]] (owns the lock protocol and `op_results`), [[035-vf06-push-per-device]] (owns push delivery).

## 0. Scope and how to read this

- Amendment to v2 §2.3 (items 5, 6), §2.11 (Report), §4.2 (policies for `profiles`, `projects`, `reports`) and the v2.1 §3.3 contract table. Where this file and v2/v2.1 disagree, this file wins for those items.
- Resolves F18 (grant path), F19 (liveness before relationship exceptions), F20 (reporter hide for every subject type).
- Gates B02 ([[013-b02-backend-backbone]]: conventions, helpers, tables) and B10 ([[021-b10-safety]]: writers, auto-hide, tests).
- The SQL in section 7 is a **sketch inside this doc**. Nothing is added under `supabase/`. Names and shapes are binding; bodies may be tightened by the owning slice.
- Tests are the exit criteria of [[034-vf05-reports-visibility]] (IDs `G`, `R`, `L`, `H`). This doc cites them by ID.
- Tags: **[design]** = my call. **[unverified]** = needs a live proof named in the ticket.

## 1. Plain language

- When you report something, the database files the report and hides the thing for you, permanently. You never see it again, even after relaunch, on another device, or if a moderator later dismisses the report.
- A hidden, suspended, deleting or deleted person never becomes visible just because you once talked to them. The only exceptions are narrow and named: you still see the *name* of a hidden-from-discovery person you already chat with, and you still see the *history* of a person who deleted their account (as "Deleted user").
- Nobody can call the filing function with made-up inputs. The filing function takes no reporter id and no snapshot. It works them out itself from the signed-in session and the database.

## 2. Decisions

| # | Decision | Resolves |
|---|---|---|
| A1 | `public.submit_report` is `SECURITY DEFINER` like every other RPC. **No invoker exception.** The v2 "invoker reads via RLS, then calls a definer" design is dropped. | F18 |
| A2 | `private.file_report` is a definer owned by `postgres`. **EXECUTE is granted to nobody** (revoked from `public`, `anon`, `authenticated`, `service_role`). It runs only because the owner-run `submit_report` calls it. It stays **off** the execution allowlist. | F18 |
| A3 | `file_report` takes no reporter id and no snapshot. It re-derives identity (`auth.uid()` + `viewer_ok`), subject visibility, limits and the snapshot itself. | F18 |
| A4 | RLS and the report path share **one visibility core** (`private.subject_visible(viewer, type, id)`). RLS policies call one-argument wrappers of it. A parity test proves the report path cannot drift from RLS. | F18, F19 |
| A5 | **Subject predicate first.** Every visibility function applies viewer liveness, then subject liveness (owner active, not suspended/deleting/gone, row not moderation-hidden), then reporter hide, **then** relationship or public branches. A relationship can never resurrect a subject that failed liveness. | F19 |
| A6 | Exactly **two** named exceptions after the liveness layer: (E1) `hidden_name`: an existing counterpart may read the *row* of a moderation-hidden or reporter-hidden profile whose account is active; the profile **page** stays denied. (E2) `history`: messages and terminal requests of a *deleting or gone* author stay readable to the counterpart (D42, D49). Nothing else. | F19 |
| A7 | One dedicated table `public.reporter_hides(reporter_id, subject_type, subject_id)`, written only by `file_report`. It replaces v2's reuse of `recommendation_feedback.hide` (which `clear_feedback` could undo and which is a ranking signal, not a visibility rule). | F20 |
| A8 | Every table policy and every definer RPC that returns content goes through the visibility core, so the reporter hide is enforced at the **table**, not per screen. Realtime and signed Storage URLs inherit it because both re-evaluate table/`storage.objects` RLS. | F20 |
| A9 | Reporter hide is **permanent in v0** and survives dismissal. No "show again" in v0. | F20 |
| A10 | Profile report hides the profile *page*, discovery and that person's projects/posts/links for the reporter. It does **not** sever an existing chat or request (that is Block / Remove from Crew; the confirmation offers "Also block"). | F20 |
| A11 | Reporting a request does not change its state. It is hidden for the reporter and cannot be accepted by them; the sender sees nothing change. | F20 |
| A12 | B02 creates the report tables, the visibility core and wrappers (empty, no writers). Every later slice writes its policies against the wrappers from day one. B10 adds the writers, auto-hide and the end-to-end tests. | F19, F20 |

## 3. (a) The grant path for filing reports

### 3.1 Why v2's shape fails

v2 §2.3 says all public RPCs are `security definer`. v2 §2.11 says `submit_report` is `security invoker` and calls `private.file_report`. An invoker function runs as `authenticated`, so it needs EXECUTE on the callee. The callee is not on the allowlist (v2 §2.3.5). Either the call fails, or someone leaves default PUBLIC execute on a private evidence writer. Neither is a reviewed privilege model (F18).

### 3.2 Chosen: definer wrapper, definer callee, no grant to the callee

```
client ──(authenticated)──▶ public.submit_report   definer, owner postgres, EXECUTE: authenticated only
                                   │  caller_ok, op_results reservation (VF04), input shape
                                   ▼
                            private.file_report     definer, owner postgres, EXECUTE: nobody
                                   │  identity, visibility, dedupe, limit, snapshot, writes, auto-hide
                                   ▼
        public.reports · public.reporter_hides · private.report_evidence · subject.hidden_at
```

A function called from inside another function executes with the **calling function's owner's** privileges for the EXECUTE check. `submit_report` is owned by `postgres`, so it may call `file_report` without any role holding EXECUTE on it. `authenticated` therefore never needs a grant to the writer.

### 3.3 Exact signatures, owners, grants

| Function | Kind | Owner | `search_path` | EXECUTE |
|---|---|---|---|---|
| `public.submit_report(p_subject_type public.report_subject_type, p_subject_id uuid, p_category public.report_category, p_context text, p_op_id uuid) returns jsonb` | definer | `postgres` | `''` | `authenticated` only. Revoked from `public`, `anon`, `service_role` |
| `private.file_report(p_subject_type public.report_subject_type, p_subject_id uuid, p_category public.report_category, p_context text) returns table(report_id uuid, deduped boolean, subject_owner_id uuid)` | definer | `postgres` | `''` | **none** |
| `private.report_snapshot(p_type public.report_subject_type, p_id uuid) returns jsonb` | definer | `postgres` | `''` | none |
| `private.autohide_after_report(p_type public.report_subject_type, p_id uuid) returns void` | definer | `postgres` | `''` | none |
| `private.subject_gate`, `private.subject_visible`, `private.account_state`, `private.viewer_ok`, `private.history_carveout`, `private.is_reporter_blind`, `private.has_relationship`, `private.discovery_ok` | definer / sql | `postgres` | `''` | none (called only by other owner-run functions) |
| Policy wrappers (section 3.5) | definer | `postgres` | `''` | `authenticated` only (they are called from RLS policies, which evaluate as the invoker) |

`submit_report` result: `{report_id, hidden: true, offer_block: bool, deduped: bool}`. It never returns counts, other reporters, snapshot, hidden state of the owner, or whether auto-hide fired.

### 3.4 Revoke-default rules (apply to every migration, B02 onward)

1. **Defaults off, once, in B02:**
   ```sql
   alter default privileges for role postgres revoke execute on functions from public;
   alter default privileges for role postgres in schema private revoke execute on functions from anon, authenticated, service_role;
   alter default privileges for role postgres in schema public  revoke execute on functions from anon, authenticated, service_role;
   ```
   Supabase installs default privileges that grant new `public` functions to `anon`, `authenticated`, `service_role`. The third statement removes that. [unverified on hosted Supabase; local proof: test G6.]
2. **Belt and braces, per function** (existing repo convention): the migration that creates a function ends with `revoke all on function … from public, anon, authenticated;` and then a single `grant execute … to authenticated` only for allowlisted names.
3. **Allowlist file.** `supabase/tests/database/function_grants.allowlist` lists every function with EXECUTE for `authenticated`, as `schema.name(identity args)`. The catalog test (G2) asserts set equality in both directions: an extra grant or a missing one fails the build. `anon` and `public` have **no** EXECUTE on anything in `public` or `private` (Auth hooks and extensions aside).
4. **Allowlist entries added by this doc** (on top of v2 §2.3.5: `is_blocked`, `caller_ok`, `is_participant`, `can_view_profile`, `can_view_project`, `favourites_visible`):
   - `private.can_read_profile_row(uuid)`
   - `private.can_view_collab_post(uuid)`
   - `private.can_view_portfolio_source(uuid)`
   - `private.can_view_request(uuid)`
   - `private.can_read_message(uuid)`
   - `private.can_read_message_body(uuid)` (v2.1 §2.2)
   - `private.can_read_media_path(text, text)` (Storage policy)
   - `public.submit_report(public.report_subject_type, uuid, public.report_category, text, uuid)`
   - **Not** on the allowlist: `private.file_report`, `private.report_snapshot`, `private.autohide_after_report`, and every core function in the table above.
5. **Invoker functions in `public`: only trigger helpers.** A catalog test (G7) lists every `public` function with `prosecdef = false`; the expected set is `{set_updated_at}`. Any new invoker function needs an entry and a written reason.

### 3.5 `search_path` rule

- Every function in `public` and `private`, definer or not, declares `set search_path = ''` (stored as `search_path=""`).
- Everything except `pg_catalog` is schema-qualified: `public.profiles`, `private.viewer_ok`, `auth.uid()`, `extensions.citext`. `pg_catalog` is always searched implicitly; do not rely on `pg_temp`.
- **citext trap:** with an empty path the `citext` operators are not found. Inside functions compare `handle::text`, or write `operator(extensions.=)`. Never compare a citext column to a literal unqualified.
- Test G1: every function in `public`/`private` that is not extension-owned has `proconfig` containing `search_path=""` and `proowner = postgres`. Test G9: a temp table named `reports` created by the caller does not capture the insert.

### 3.6 Direct-call surfaces (what "helper calls rejected" means)

- SQL as `authenticated`: `select private.file_report(…)` → `42501`. As `anon`: `public.submit_report` → `42501`. As `service_role`: `private.file_report` → `42501` (the Edge Functions never need it).
- PostgREST: `private` is not in `[api] schemas`. `POST /rpc/file_report` → `404 PGRST202`; with `Content-Profile: private` → `406 PGRST106`. `GET /rest/v1/report_evidence` → `404`. No test claims a direct HTTP route exists to the private schema (matches the F18 caveat).

### 3.7 Rejected alternatives

| Option | Why not |
|---|---|
| Invoker `submit_report` + `grant execute … file_report to authenticated` | Puts a privileged evidence writer on the authenticated allowlist; two code paths decide authorization; the callee would have to distrust its own caller (forged snapshot/reporter). |
| Invoker `submit_report` + default PUBLIC execute on the callee | Not a privilege model. |
| Definer `submit_report` that trusts a snapshot built by a separate invoker read | Same forged-input surface. |
| Chosen: definer + shared visibility core + parity test | One authorization source, nothing granted to the writer, drift is a failing test. |

## 4. (b) Subject liveness before relationship exceptions

### 4.1 Layers (apply in this order in every visibility function)

Boolean AND is order-free in SQL, so "before" means **logical precedence**: no later layer can return `true` once an earlier layer returned `false`, except where the layer itself names an exception. The functions are written as early returns so the precedence is also literal.

| Layer | Check | On failure |
|---|---|---|
| L0 Viewer | `viewer_ok(viewer)`: profile exists, `account_status = 'active'`, `legal_acceptances.age_confirmed` | false |
| L1 Subject liveness | `subject_gate` returns state: `gone` (no row), `owner_suspended`, `owner_deleting` (deleting, or author already null), `moderation_hidden` (row `hidden_at`, or profile `hidden_at`), `live` | `gone`, `owner_suspended` → false. `owner_deleting` → false unless **E2** (history, message/request only) |
| L1b Block | `is_blocked(viewer, owner)` either direction (owner not null) | false (blocked side learns nothing, v2 §2.11) |
| L2 Own content | `owner = viewer` | true (after L0; deleting owners fail L0) |
| L3 Moderation hide | `moderation_hidden` | false for non-owners. Exceptions: **E1** (profile *row*), and messages (the *envelope* stays readable; the body is gated by `can_read_message_body`, v2.1 §2.2) |
| L4 Reporter hide | `is_reporter_blind(viewer, type, id, owner)`: a `reporter_hides` row for the subject, or (for project, collab_post, portfolio_source) for the owner's profile | false. Exception: profile **row** with a relationship (E1) |
| L5 Branches | per type (4.2): public branch, relationship branch, membership branch | true/false |

### 4.2 Per subject type

| Subject | Owner (gate) | Deny states at L1 | Branches at L5 | Relationship may extend? |
|---|---|---|---|---|
| profile page / discovery (`can_view_profile`) | the profile | suspended, deleting, gone, hidden | onboarded and live | **No branch.** Strict. |
| profile row (`can_read_profile_row`) | the profile | suspended, deleting, gone | strict page predicate, **or** `has_relationship(viewer, id)` | Yes, only if state is `live` or `moderation_hidden` (**E1**). Reporter-hidden profile with a relationship is also readable here. |
| project | `owner_id` | owner suspended/deleting/gone; project `hidden_at` | public: status in published/closed/past **and** owner profile onboarded and not `hidden_at`; member: `project_members` row and status not draft | Member branch survives an owner whose *profile* is hidden, never a suspended/deleting owner or a hidden project (F19). |
| collab post (photo/video) | `owner_id` | owner not live; post `hidden_at` | public: owner profile onboarded and not hidden | No. |
| link/embed (`portfolio_sources`) | `profile_id` | owner not live; `hidden_at` | public: consent + `link_status` ok + owner page-visible | No. |
| request | `sender_id` | sender suspended → false; sender deleting/gone → **E2**: only terminal requests (`status <> 'pending'`); request `hidden_at` | recipient: `recipient_id = viewer`, `hidden_at` null; sender: L2 | No (parties only). Recipient suspended/deleted does not hide the sender's own record. |
| message (envelope) | `sender_id` | sender suspended → false; sender deleting/gone → **E2** (history, read-only, "Deleted user") | participant (`is_participant` core) and conversation not block-closed | No. |
| message body | same | as envelope, plus `erased_at` set → false; `hidden_at` and viewer not sender → false | as envelope | No. |

Unreadable counterparts render as **"Deleted user"** (D42) whether they are suspended, deleting or gone: the client cannot tell them apart from "no row", and must not.

### 4.3 Descendants

A descendant is readable only if its parent subject passes the core **and** its own predicate:

| Descendant | Parent gate |
|---|---|
| `profile_roles`, `favourites`, `portfolio_sources` | `can_view_profile(profile_id)` (strict, so no hidden/blind/suspended owner leaks roles or favourites through a relationship) |
| `project_roles`, `project_members` | `can_view_project(project_id)` |
| `message_bodies` | `can_read_message_body(message_id)` |
| `storage.objects` in `user-media`, `user-video` | `can_read_media_path(bucket, name)` → parent post/project through the core |
| `request_decline_reasons` | recipient only, plus `can_view_request` |

### 4.4 Definer paths that bypass RLS must call the core

These run as `postgres` and ignore RLS, so each calls the predicate explicitly. Relationship exceptions are **not** available in them.

| Path | Predicate | Result for a non-live target |
|---|---|---|
| `recommend` Stage 0 | `private.discovery_ok(viewer, type, id)`: state `live`, not blocked, not reporter-blind (incl. owner), public branch only, **no relationship branch** | candidate dropped. Test L7 builds viewers who have a request, connection, conversation or membership with a hidden/suspended/deleting/gone/blind target and asserts none is returned |
| `send_request` (all kinds), `respond_request`, `withdraw_request` | `can_read_profile_row`/`can_view_*` for the counterpart and project | `not_found` (same text and shape as a missing id), no outbox row |
| `record_feedback` | `discovery_ok` | `not_found` |
| `submit_report` | the core, same as RLS | `not_found` |
| `send_message` | connection `active` (v2.1 §1) and both parties live | `stale_state`/`not_found` as v2.1 |
| push delivery (`send-push`) | outbox row's subject must pass `not reporter-hidden` for the recipient (kinds `request`, `message`) | `sent` with `skipped_reason = 'reporter_hidden'`; B08 sets `outbox.subject_id` to the message id; VF06 owns the delivery code |

### 4.5 The only intended exceptions, restated

- **E1 `hidden_name`** (v2 C-08): the profile *row* (handle, name, avatar, and, unavoidably, the other public row columns) for an existing counterpart of an active but moderation-hidden or reporter-hidden profile. The client renders name and avatar only and opens no profile page. Residual: bio/city are in the REST row for those counterparts. A stub view would remove it; not required [design].
- **E2 `history`** (D42, D49): messages and terminal requests authored by a *deleting or gone* author. Not for suspended authors.

## 5. (c) Persistent reporter hide for every subject type

### 5.1 Subject types and table

`public.report_subject_type` = `profile | project | collab_post | request | message | portfolio_source`. `collab_post` covers photo and video (D55). `portfolio_source` covers links and embeds.

`public.reporter_hides(reporter_id, subject_type, subject_id, report_id, created_at)`; PK `(reporter_id, subject_type, subject_id)`. Owner-only SELECT, no client writes. Written only by `file_report`. FKs: reporter `on delete cascade`; `report_id` `on delete set null` (a retention purge of reports must not un-hide). `subject_id` is polymorphic, so no FK; orphans are harmless (uuids are not reused) and the deletion job sweeps them (B17).

Not added to the `supabase_realtime` publication in v0 (test H11). Other devices learn on launch, foreground and reconnect (5.4).

### 5.2 What each hide covers

| Subject | Hidden for the reporter | Not affected |
|---|---|---|
| profile | profile page, Home/people, Search, recommend, deep links, and that person's projects, posts and links (derived) | an existing chat, requests and the person's name/avatar inside them (E1). Use Block / Remove from Crew. |
| project | cards, detail, recommend, deep links, `project_roles`/`project_members` rows, cover signing | requests that reference it (shown as "Project unavailable") |
| collab post | grid, profile list, viewer, deep link, thumb/full/poster/video signing | the author's other posts (report the profile for that) |
| request | Suki lists, detail, counts, accept/decline/withdraw (all `not_found`) | request state (A11): sender sees no change, request expires normally |
| message | thread page, gap-recovery fetch, body fetch, Inbox preview, unread dot, Realtime events, push | other messages in the chat |
| link/embed | profile links list, embed descriptor | the profile |

### 5.3 Read paths

Everything funnels through the core (section 7), so a path is covered if it reads a table through RLS, a definer RPC that calls the core, or Storage/Realtime (which re-run RLS).

| Path | REST | RPCs | Realtime | Signed Storage |
|---|---|---|---|---|
| profile | `profiles` policy: `can_read_profile_row`; descendants `can_view_profile` | `recommend` (`discovery_ok`), `send_request`, `record_feedback` | none (no profile publication) | `avatars` is public, **accepted exception** (v2 §2.7): the server cannot hide it; the client suppresses via the ledger and the profile page is already denied |
| project | `projects` policy: `can_view_project` | `recommend`, `send_request` (join/invite), `record_feedback` | none | cover path via `can_read_media_path` |
| collab post | `collab_posts` policy: `can_view_collab_post` (Search grid and profile lists are plain selects; any future `search_*` RPC must call the core) | `record_feedback` | none | `user-media` / `user-video` SELECT policy → `can_read_media_path`; `createSignedUrl` evaluates it, so **new** URLs are refused immediately; URLs minted before the report live out their 10-minute TTL (v2 §2.7, accepted) |
| request | `requests` policy: `can_view_request` | `respond_request`, `withdraw_request`, `send_request` (duplicate guard reads the true row but returns only `already_pending`/`not_found` as today) | none | none |
| message | `messages` policy: `can_read_message`; `message_bodies`: `can_read_message_body`; embedded `messages(message_bodies(body))` selects inherit both | `mark_read` (no content), Inbox/unread computed from visible envelopes only (REST), `send_message` unaffected | `postgres_changes` on `messages` re-checks the subscriber's SELECT policy per event: INSERT/UPDATE events for a hidden-by-me message are not delivered to me; `message_bodies` is not published (v2.1 M1). **[unverified]** live test H4 | none |
| link/embed | `portfolio_sources` policy: `can_view_portfolio_source` | none | none | none (provider content is fetched by the client from the descriptor; no descriptor, no embed) |

Realtime cannot signal "this row just became invisible to you". So: (1) the app applies the hide locally the moment `submit_report` returns; (2) it re-syncs the ledger (5.4) on launch, foreground and reconnect; (3) the server guarantees no later event for that id reaches the reporter.

### 5.4 Client ledger and cache rules

- After `submit_report` succeeds: add `(type, id)` to the in-memory hide set, purge caches for that subject (body cache, image cache by object path, lists), show the "Thanks" sheet with "Also block".
- On launch, foreground and Realtime reconnect: `select subject_type, subject_id, created_at from reporter_hides where created_at > :cursor order by created_at`. Apply as above. This is how a second device or a reinstall converges. Cache lives in `SessionScope` and is purged on sign-out (v2 §2.2).
- The ledger is the reporter's own data only (owner-only RLS). The subject owner can never see it.

### 5.5 Evidence does not leak

- `reports`: column-level `SELECT (id, reporter_id, subject_type, subject_id, category, status, created_at)` for the reporter only. No notes, no snapshot, no counts.
- `private.report_evidence(report_id, subject_owner_id, snapshot, reviewer_note, reviewed_at)`: no grant to any client role. Service role and dashboard only.
- Snapshot is built by `report_snapshot` from a **per-type allowlist** of public columns only (never `work_mode`, `compensation_preference`, favourites, taste, onboarding state). Test R1 asserts keys ⊆ allowlist.
- Dismissal clears the subject's moderation `hidden_at` for everyone **except** it never touches `reporter_hides` (test H2).

### 5.6 Lifecycle

| Event | Effect on the hide |
|---|---|
| Report dismissed / actioned | none |
| Reporter blocks or unblocks the owner | none |
| Subject owner edits or deletes the subject | none (orphan row swept at deletion) |
| Reporter deletes account | cascade |
| Reports retention purge | none (`report_id` set null) |

## 6. Slice ownership and contract versions

Replaces the `can_view_profile` row in v2.1 §3.3.

| Item | B02 (013) | Later |
|---|---|---|
| Defaults off, allowlist file, catalog tests G1, G2, G6, G7, G9 | yes | each slice adds its names to the allowlist |
| `viewer_ok`, `caller_ok`, `account_state`, `subject_gate`, `subject_visible` core, `history_carveout`, `is_reporter_blind`, `has_relationship` (profile-only until B07) | yes | each slice adds its subject type to `subject_gate` |
| Enums `report_subject_type`, `report_category`; tables `reports`, `reporter_hides`, `private.report_evidence` (empty, no writers) | yes | |
| `can_view_profile` **v1** = strict page predicate with liveness first and reporter-blind | yes | v2 (B07) adds `can_read_profile_row` with E1; v3 (B10) no signature change, adds auto-hide writers |
| `can_view_project`, `can_view_collab_post`, `can_view_portfolio_source`, `can_view_request`, `can_read_message[_body]`, `can_read_media_path` | | created by the slice that creates the table (B06, B12/B13, B07, B08, B11); each ships its `L` and `H` tests with fixtures inserted directly into `reporter_hides` |
| `submit_report`, `file_report`, `report_snapshot`, `autohide_after_report`, Report UI on every surface so far, tests R, G3–G5, G8, H end to end | | B10 |
| Push delivery check for hidden subjects | | B18 (VF06) |

**Lock protocol** (to be merged into the master order owned by [[033-vf04-concurrency-readiness]]): `file_report` takes (0) the reporter's profile row `FOR SHARE` together with, for a profile subject, the subject profile row `FOR NO KEY UPDATE` (never a share-to-update upgrade, which deadlocks two concurrent reporters), ascending by id; (1) an advisory lock keyed `report:<reporter>` for the daily limit, then `report-subject:<type>:<id>` to serialize auto-hide counting; (2–5) the subject's own row at its normal class only when auto-hide updates it. It takes no pair advisory lock and no conversation lock.

## 7. Draft migration SQL sketch (not applied; not under `supabase/`)

```sql
-- ===== B02: conventions =====================================================
alter default privileges for role postgres revoke execute on functions from public;
alter default privileges for role postgres in schema private revoke execute on functions from anon, authenticated, service_role;
alter default privileges for role postgres in schema public  revoke execute on functions from anon, authenticated, service_role;

create type public.report_subject_type as enum
  ('profile','project','collab_post','request','message','portfolio_source');
create type public.report_category as enum   -- union of R-BE 1.2 and R-IOS 4.2, finalised in B10
  ('harassment','spam','impersonation','nudity_sexual','hate','violence','self_harm','ip','minor_safety','other');

create table public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  subject_type public.report_subject_type not null,
  subject_id uuid not null,
  category public.report_category not null,
  status text not null default 'open' check (status in ('open','reviewing','actioned','dismissed')),
  created_at timestamptz not null default now(),
  closed_at timestamptz,
  unique (reporter_id, subject_type, subject_id)          -- dedupe backstop (nulls distinct after reporter deletion)
);
create table public.reporter_hides (
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  subject_type public.report_subject_type not null,
  subject_id uuid not null,
  report_id uuid references public.reports(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (reporter_id, subject_type, subject_id)
);
create table private.report_evidence (
  report_id uuid primary key references public.reports(id) on delete cascade,
  subject_owner_id uuid references public.profiles(id) on delete set null,
  subject_owner_deleted_at timestamptz,
  snapshot jsonb not null,
  reviewer_note text,
  reviewed_at timestamptz
);
alter table public.reports enable row level security;
alter table public.reporter_hides enable row level security;
revoke all on public.reports, public.reporter_hides from anon, authenticated;
revoke all on private.report_evidence from public, anon, authenticated, service_role;
grant select (id, reporter_id, subject_type, subject_id, category, status, created_at)
  on public.reports to authenticated;
grant select on public.reporter_hides to authenticated;
create policy reports_read_own on public.reports for select to authenticated
  using (reporter_id = (select auth.uid()));
create policy reporter_hides_read_own on public.reporter_hides for select to authenticated
  using (reporter_id = (select auth.uid()));

-- ----- viewer and subject liveness ------------------------------------------
create function private.viewer_ok(p_viewer uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.profiles p
                  where p.id = p_viewer and p.account_status = 'active')
     and exists (select 1 from public.legal_acceptances l
                  where l.profile_id = p_viewer and l.age_confirmed);
$$;
create function private.caller_ok() returns boolean
language sql stable security definer set search_path = '' as $$
  select private.viewer_ok((select auth.uid()));
$$;
create function private.account_state(p_id uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select case p.account_status::text
                            when 'active' then 'live'
                            when 'suspended' then 'owner_suspended'
                            else 'owner_deleting' end
                     from public.profiles p where p.id = p_id), 'gone');
$$;
create function private.history_carveout(p_type public.report_subject_type, p_state text)
returns boolean language sql immutable set search_path = '' as $$
  select p_type in ('message','request') and p_state = 'owner_deleting';   -- E2, nothing else
$$;
create function private.is_reporter_blind(p_viewer uuid, p_type public.report_subject_type,
                                          p_id uuid, p_owner uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.reporter_hides h
     where h.reporter_id = p_viewer
       and ((h.subject_type = p_type and h.subject_id = p_id)
         or (p_type in ('project','collab_post','portfolio_source')
             and h.subject_type = 'profile' and h.subject_id = p_owner)));
$$;

-- gate: who owns it, and what state is the subject in? (L1)
create function private.subject_gate(p_type public.report_subject_type, p_id uuid,
                                     out o_owner uuid, out o_state text)
language plpgsql stable security definer set search_path = '' as $$
declare v_found boolean := false; v_hidden timestamptz;
begin
  if p_type = 'profile' then
    select true, x.id, x.hidden_at into v_found, o_owner, v_hidden from public.profiles x where x.id = p_id;
  elsif p_type = 'project' then
    select true, x.owner_id, x.hidden_at into v_found, o_owner, v_hidden from public.projects x where x.id = p_id;
  elsif p_type = 'collab_post' then
    select true, x.owner_id, x.hidden_at into v_found, o_owner, v_hidden from public.collab_posts x where x.id = p_id;
  elsif p_type = 'portfolio_source' then
    select true, x.profile_id, x.hidden_at into v_found, o_owner, v_hidden from public.portfolio_sources x where x.id = p_id;
  elsif p_type = 'request' then
    select true, x.sender_id, x.hidden_at into v_found, o_owner, v_hidden from public.requests x where x.id = p_id;
  elsif p_type = 'message' then
    select true, x.sender_id, x.hidden_at into v_found, o_owner, v_hidden from public.messages x where x.id = p_id;
  end if;
  if not v_found then o_state := 'gone'; return; end if;
  o_state := case when o_owner is null then 'owner_deleting' else private.account_state(o_owner) end;
  if o_state = 'live' and v_hidden is not null then o_state := 'moderation_hidden'; end if;
end $$;

-- ----- the visibility core (non-profile subjects) ----------------------------
create function private.subject_visible(p_viewer uuid, p_type public.report_subject_type, p_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare g record;
begin
  if p_type = 'profile' then
    return private.can_read_profile_row_for(p_viewer, p_id);       -- profiles have their own pair below
  end if;
  -- L0 viewer
  if not private.viewer_ok(p_viewer) then return false; end if;
  select * into g from private.subject_gate(p_type, p_id);
  -- L1 subject liveness: mandatory, nothing below may override it
  if g.o_state in ('gone','owner_suspended') then return false; end if;
  if g.o_state = 'owner_deleting' and not private.history_carveout(p_type, g.o_state) then return false; end if;
  -- L1b block (either direction)
  if g.o_owner is not null and g.o_owner <> p_viewer and private.is_blocked(p_viewer, g.o_owner) then return false; end if;
  -- L2 own content
  if g.o_owner = p_viewer then return true; end if;
  -- L3 moderation hide (message envelopes stay readable; body is gated separately)
  if g.o_state = 'moderation_hidden' and p_type <> 'message' then return false; end if;
  -- L4 reporter hide (own + derived from the owner's profile)
  if private.is_reporter_blind(p_viewer, p_type, p_id, g.o_owner) then return false; end if;
  -- L5 branches
  if p_type = 'project' then
    return exists (
      select 1 from public.projects j
       where j.id = p_id
         and ( (j.status in ('published','closed','past')
                and exists (select 1 from public.profiles o
                             where o.id = j.owner_id and o.onboarding_completed_at is not null
                               and o.hidden_at is null))
            or (j.status <> 'draft'
                and exists (select 1 from public.project_members m
                             where m.project_id = j.id and m.profile_id = p_viewer))));
  elsif p_type = 'collab_post' then
    return exists (select 1 from public.collab_posts c join public.profiles o on o.id = c.owner_id
                    where c.id = p_id and o.onboarding_completed_at is not null and o.hidden_at is null);
  elsif p_type = 'portfolio_source' then
    return exists (select 1 from public.portfolio_sources s join public.profiles o on o.id = s.profile_id
                    where s.id = p_id and s.public_display_consent and s.link_status = 'ok'
                      and o.onboarding_completed_at is not null and o.hidden_at is null);
  elsif p_type = 'request' then
    return exists (select 1 from public.requests r
                    where r.id = p_id and r.recipient_id = p_viewer and r.hidden_at is null
                      and (g.o_state = 'live' or r.status <> 'pending'));          -- E2: terminal only
  elsif p_type = 'message' then
    return exists (select 1 from public.messages m
                     join public.conversations c on c.id = m.conversation_id
                    where m.id = p_id and c.closed_reason is distinct from 'blocked'
                      and private.is_participant_for(p_viewer, m.conversation_id));
  end if;
  return false;
end $$;

-- profile: strict page predicate vs row-read with the E1 exception
create function private.can_view_profile_for(p_viewer uuid, p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.viewer_ok(p_viewer)
     and exists (select 1 from public.profiles p
                  where p.id = p_id and p.account_status = 'active' and p.hidden_at is null
                    and (p.id = p_viewer or p.onboarding_completed_at is not null))
     and (p_id = p_viewer
          or (not private.is_blocked(p_viewer, p_id)
              and not private.is_reporter_blind(p_viewer, 'profile', p_id, p_id)));
$$;
create function private.can_read_profile_row_for(p_viewer uuid, p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.viewer_ok(p_viewer)
     and private.account_state(p_id) = 'live'                       -- L1 first: suspended/deleting/gone => false
     and (p_id = p_viewer or not private.is_blocked(p_viewer, p_id))
     and ( private.can_view_profile_for(p_viewer, p_id)              -- strict page
        or private.has_relationship(p_viewer, p_id) );               -- E1, only reachable when account is live
$$;
-- (has_relationship: any request, conversation (not block-closed) or shared project membership, either direction)

-- discovery: strict public branch, never a relationship
create function private.discovery_ok(p_viewer uuid, p_type public.report_subject_type, p_id uuid)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare g record;
begin
  select * into g from private.subject_gate(p_type, p_id);
  return g.o_state = 'live'
     and g.o_owner is not null and g.o_owner <> p_viewer
     and not private.is_blocked(p_viewer, g.o_owner)
     and not private.is_reporter_blind(p_viewer, p_type, p_id, g.o_owner)
     and case p_type
           when 'profile' then private.can_view_profile_for(p_viewer, p_id)
           when 'project' then exists (select 1 from public.projects j
                                        where j.id = p_id and j.status = 'published' and j.expires_at > now())
           else false end;
end $$;

-- one-argument wrappers: the only functions policies call (allowlisted to authenticated)
create function private.can_view_profile(p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.can_view_profile_for((select auth.uid()), p_id) $$;
create function private.can_read_profile_row(p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.can_read_profile_row_for((select auth.uid()), p_id) $$;
create function private.can_view_project(p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.subject_visible((select auth.uid()), 'project', p_id) $$;
-- same one-liners: can_view_collab_post, can_view_portfolio_source, can_view_request, can_read_message
create function private.can_read_message_body(p_id uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.subject_visible((select auth.uid()), 'message', p_id)
     and exists (select 1 from public.messages m
                  where m.id = p_id and m.erased_at is null
                    and (m.hidden_at is null or m.sender_id = (select auth.uid())));
$$;
create function private.can_read_media_path(p_bucket text, p_name text) returns boolean
language plpgsql stable security definer set search_path = '' as $$
declare v_parts text[] := storage.foldername(p_name); v_id uuid;
begin
  -- <uid>/collab/<post_id>/... or <uid>/project/<project_id>/...
  begin v_id := v_parts[3]::uuid; exception when invalid_text_representation then return false; end;
  if v_parts[2] = 'collab'  then return private.subject_visible((select auth.uid()), 'collab_post', v_id); end if;
  if v_parts[2] = 'project' then return private.subject_visible((select auth.uid()), 'project', v_id); end if;
  return false;
end $$;

-- policies (pattern; each slice writes its own against the wrappers)
create policy profiles_read_others on public.profiles for select to authenticated
  using (private.can_read_profile_row(id));                           -- own row has its own exception policy
create policy projects_read on public.projects for select to authenticated
  using (private.can_view_project(id));
create policy collab_posts_read on public.collab_posts for select to authenticated
  using (private.can_view_collab_post(id));
create policy portfolio_sources_read on public.portfolio_sources for select to authenticated
  using (private.can_view_portfolio_source(id));
create policy requests_read on public.requests for select to authenticated
  using (private.can_view_request(id));
create policy messages_read on public.messages for select to authenticated
  using (private.can_read_message(id));
create policy message_bodies_read on public.message_bodies for select to authenticated
  using (private.can_read_message_body(message_id));
create policy profile_roles_read on public.profile_roles for select to authenticated
  using (private.can_view_profile(profile_id));
-- restrictive policies stay as v2 (caller_ok, block). Storage:
create policy user_media_read on storage.objects for select to authenticated
  using (bucket_id in ('user-media','user-video')
         and ( ((storage.foldername(name))[1] = (select auth.uid())::text and private.caller_ok())
            or private.can_read_media_path(bucket_id, name) ));

-- grants for every function above: revoke first, allowlist second
revoke all on all functions in schema private from public, anon, authenticated, service_role;
grant execute on function
  private.caller_ok(), private.can_view_profile(uuid), private.can_read_profile_row(uuid),
  private.can_view_project(uuid), private.can_view_collab_post(uuid),
  private.can_view_portfolio_source(uuid), private.can_view_request(uuid),
  private.can_read_message(uuid), private.can_read_message_body(uuid),
  private.can_read_media_path(text, text)
  to authenticated;     -- plus is_blocked, is_participant, favourites_visible as in v2 §2.3.5

-- ===== B10: writers ==========================================================
create function private.file_report(p_subject_type public.report_subject_type, p_subject_id uuid,
                                    p_category public.report_category, p_context text)
returns table(report_id uuid, deduped boolean, subject_owner_id uuid)
language plpgsql security definer set search_path = '' as $$
declare
  v_me uuid := (select auth.uid());
  v_owner uuid; v_state text; v_id uuid; v_ctx text := nullif(btrim(p_context), '');
begin
  -- identity: never a parameter
  if v_me is null or not private.viewer_ok(v_me) then raise exception 'not_found'; end if;
  if v_ctx is not null and char_length(v_ctx) > 500 then raise exception 'invalid_input'; end if;

  -- locks (order per VF04): reporter profile (+ subject profile NO KEY UPDATE), then advisory locks
  if p_subject_type = 'profile' and p_subject_id < v_me then
    perform 1 from public.profiles where id = p_subject_id for no key update;   -- ascending id; never share->update
    perform 1 from public.profiles where id = v_me for share;
  elsif p_subject_type = 'profile' and p_subject_id > v_me then
    perform 1 from public.profiles where id = v_me for share;
    perform 1 from public.profiles where id = p_subject_id for no key update;
  else
    perform 1 from public.profiles where id = v_me for share;   -- (subject == me: profile reports of self are refused by visibility/owner rules)
  end if;
  perform pg_advisory_xact_lock(hashtextextended('report:' || v_me::text, 0));
  perform pg_advisory_xact_lock(hashtextextended('report-subject:' || p_subject_type::text || ':' || p_subject_id::text, 0));

  -- dedupe: already reported by me -> same answer, consumes no quota, adds no count
  select r.id into v_id from public.reports r
   where r.reporter_id = v_me and r.subject_type = p_subject_type and r.subject_id = p_subject_id;
  if found then return query select v_id, true, (select g.o_owner from private.subject_gate(p_subject_type, p_subject_id) g); return; end if;

  -- subject: the SAME core RLS uses. Not visible to me == not_found.
  if not private.subject_visible(v_me, p_subject_type, p_subject_id) then raise exception 'not_found'; end if;
  select g.o_owner into v_owner from private.subject_gate(p_subject_type, p_subject_id) g;

  -- limit: 10 per rolling 24 h, serialized by the reporter advisory lock
  if (select count(*) from public.reports r
       where r.reporter_id = v_me and r.created_at > private.now() - interval '24 hours') >= 10
  then raise exception 'rate_limited'; end if;

  insert into public.reports(reporter_id, subject_type, subject_id, category)
       values (v_me, p_subject_type, p_subject_id, p_category) returning id into v_id;
  insert into private.report_evidence(report_id, subject_owner_id, snapshot)
       values (v_id, v_owner, private.report_snapshot(p_subject_type, p_subject_id));   -- from the DB, not the caller
  insert into public.reporter_hides(reporter_id, subject_type, subject_id, report_id)
       values (v_me, p_subject_type, p_subject_id, v_id) on conflict do nothing;
  perform private.autohide_after_report(p_subject_type, p_subject_id);
  return query select v_id, false, v_owner;
end $$;

create function public.submit_report(p_subject_type public.report_subject_type, p_subject_id uuid,
                                     p_category public.report_category, p_context text, p_op_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare v_me uuid := (select auth.uid()); f record; v_res jsonb;
begin
  if not private.caller_ok() then raise exception 'not_found'; end if;
  -- op_results reservation, parameter hash, replay: per VF04 (private.op_begin / op_finish)
  select * into f from private.file_report(p_subject_type, p_subject_id, p_category, p_context);
  v_res := jsonb_build_object('report_id', f.report_id, 'hidden', true, 'deduped', f.deduped,
                              'offer_block', f.subject_owner_id is not null and f.subject_owner_id <> v_me);
  return v_res;
end $$;

revoke all on function private.file_report(public.report_subject_type, uuid, public.report_category, text)
  from public, anon, authenticated, service_role;
revoke all on function public.submit_report(public.report_subject_type, uuid, public.report_category, text, uuid)
  from public, anon, service_role;
grant execute on function public.submit_report(public.report_subject_type, uuid, public.report_category, text, uuid)
  to authenticated;

-- recommend Stage 0 (definer, bypasses RLS): the predicate is explicit and has no relationship branch
--   and private.discovery_ok(v_me, 'profile', c.id)          -- people
--   and private.discovery_ok(v_me, 'project', j.id)          -- projects (also checks owner live/blind)
-- replaces v2's "viewer has not reported the target" and the feedback-table hide.
```

Notes on the sketch: `subject_visible` is always `(viewer, type, id)`; `private.now()`, `private.is_participant_for`, `private.has_relationship`, `private.autohide_after_report`, `private.report_snapshot`, `can_view_collab_post`, `can_view_portfolio_source`, `can_view_request`, `can_read_message` are one-liners of the same shape and are specified by section 3.3, 4.2 and 5.5. The lock statements are illustrative: the ascending-id pass, `FOR NO KEY UPDATE` on a profile subject and the two advisory locks are required (section 6); the final form belongs to VF04's protocol. Self-reports (`subject owner = reporter`) are refused: add `if v_owner = v_me then raise exception 'not_found'` after the visibility check (B10).

## 8. Tests

The full list is the exit-criteria section of [[034-vf05-reports-visibility]]: `G` (grants and hygiene), `R` (filing), `L` (liveness matrix and parity), `H` (reporter hide, relaunch, Realtime, Storage).

## 9. Residual risks, unverified items, and what needs the user

**Residual / accepted**
- Public `avatars` bucket cannot be hidden server-side (v2 §2.7). Mitigated by denied profile page and client suppression.
- Signed URLs minted before a report live ≤ 10 minutes (v2 §2.7).
- E1 exposes the full public profile row (including bio, city) to existing counterparts of a hidden profile. A stub view would close it.
- Second device learns of a hide on next launch, foreground or reconnect, not instantly.

**Unverified (each has a named proof)**
- Hosted Supabase default privileges match local (G6 locally; B20 smoke on staging).
- Realtime applies the subscriber's SELECT policy to UPDATE events per event (H4 live run).
- Calling an ungranted function from an owner-run definer function works as described on the pinned Postgres 17 (R1 proves it on the local stack).

**Needs the user (none blocks closing the ticket; defaults taken)**
1. Is "Deleted user" an acceptable label for suspended, deleting and gone counterparts alike? Default: yes (the client cannot and should not distinguish).
2. Reporter hide permanent with no "Show again" in v0? Default: yes.
3. Accept E1's wider REST row for hidden counterparts, or pay for a stub view? Default: accept.
4. Reporting a request does not auto-decline it (the sender sees no change). Default: yes.

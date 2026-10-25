---
id: 034
title: "VF05 Report privileges and subject visibility"
labels: [wayfinder:followup]
status: closed
blocked_by: []
assignee:
created: 2026-10-25
---

# VF05 Report privileges and subject visibility

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Resolve the invoker/definer grant path for reports, enforce subject liveness before relationship exceptions, and persist reporter hides for every subject (F18, F19, F20).

## Concept references

v2 §2.3, §2.11; verification F18–F20.

## Exit criteria (tests that prove it)

Design: [[2026-10-25-vf05-reports-visibility]]. All tests run as `authenticated` (and `anon` where stated) against the local stack from an empty DB with migrations up to the owning slice. Before B10 exists, `H` fixtures insert `reporter_hides` rows directly as `postgres`; B10 re-runs the same assertions through `submit_report`. Owners: `G1 G2 G6 G7 G9` and the fixture matrix `L9/L10` skeleton land in B02 (013); each table's `L`/`H` rows land with the slice that creates the table (B06 projects, B07 requests/profile row, B08 messages, B11 storage, B12 posts, B13 links); everything else in B10 (021).

**G. Grants and function hygiene (catalog-driven; B02)**
- G1 Every non-extension function in `public`/`private` has `proconfig` with `search_path=""` and owner `postgres`.
- G2 Set equality in both directions between `authenticated`-executable functions and `supabase/tests/database/function_grants.allowlist`; `anon` and `public` have no EXECUTE on any function in `public` or `private`.
- G3 `has_function_privilege` is false for `public`, `anon`, `authenticated`, `service_role` on `private.file_report`, `report_snapshot`, `autohide_after_report`, `subject_gate`, `subject_visible`, `discovery_ok` (B10 adds the report ones).
- G4 As `authenticated`: `select private.file_report(...)` fails `42501`; as `service_role` too.
- G5 As `anon`: `public.submit_report(...)` fails `42501`; as `authenticated` it succeeds.
- G6 A probe function created by a migration-role session with no explicit revoke has no EXECUTE for `public`, `anon`, `authenticated` in either schema (default privileges proof).
- G7 Functions in `public` with `prosecdef = false` are exactly `{set_updated_at}`; `submit_report` and `file_report` are `prosecdef = true`.
- G8 Live (Deno/PostgREST): `POST /rpc/file_report` returns 404 `PGRST202`; with `Content-Profile: private` returns 406 `PGRST106`; `GET /rest/v1/report_evidence` fails; `GET /rest/v1/reporter_hides` returns only the caller's rows; `reports` select returns only the caller's rows and no note/snapshot column.
- G9 A caller-created temp table named `reports` (and a shadow schema first in the caller's `search_path`) does not capture `submit_report`'s writes.

**R. Filing (B10)**
- R1 For each of the six subject types: reporting a visible subject creates exactly one `reports`, one `private.report_evidence` and one `reporter_hides` row; result is `{report_id, hidden:true, deduped:false, offer_block}` with no counts or owner state; snapshot keys are a subset of the per-type allowlist and never contain `work_mode`, `compensation_preference`, favourites, taste or onboarding state.
- R2 Inaccessible subjects (blocked either direction, other user's draft project, project/post/link of a hidden or suspended owner, message in a conversation the caller is not in, request the caller is not party to, another reporter-hidden subject, nonexistent id, id of the wrong type) return `not_found` with an identical message and no row written anywhere.
- R3 Forged inputs: the catalog shows no reporter or snapshot parameter; a 501-char context fails `invalid_input`; an unknown enum value fails `22P02`; null subject id fails; self-report (own profile, own project, own message) is `not_found`.
- R4 Caller states: no JWT sub, `anon`, `suspended`, `deleting`, missing `age_confirmed`, and a stale JWT of an account that became `deleting` after sign-in all get `not_found` and write nothing.
- R5 Limit: 10 reports in 24 h succeed, the 11th returns `rate_limited`; a deduped repeat consumes no quota; 11 parallel calls with distinct op ids and subjects yield exactly 10 successes (test clock via `private.now()`).
- R6 Idempotency: same `op_id` and input returns the stored result and writes once; same `op_id` with different input conflicts (VF04); a new `op_id` on an already-reported subject returns `deduped:true`, no new row, no new count.
- R7 Auto-hide: 3 distinct qualifying reporters hide the subject for everyone (state column set once, reports to `reviewing`); two qualifying plus one account under 3 days old does not; the owner, duplicates and unverified emails do not count; two reporters filing the third and fourth report concurrently leave one consistent state with no deadlock (race harness, 20 iterations, including two profile reporters of one subject profile).
- R8 Evidence privacy: no client role can select `private.report_evidence`; the reporter sees status `dismissed`/`actioned` but never notes or snapshot; the subject owner cannot read any `reports` or `reporter_hides` row about them.
- R9 Evidence survives: report a message, sender deletes the account, evidence row remains and the body is kept until the report closes (D49), then erased.

**L. Subject liveness before relationship exceptions (F19)**
- L1 Profile row and page: for a counterpart with a request, a connection, a conversation or a shared project, in each state `hidden`, `suspended`, `deleting`, `gone`: REST `profiles` returns the row only for `hidden` (E1) and never for `suspended`/`deleting`/`gone`; `can_view_profile` is false in all four; the profile is absent from `recommend`.
- L2 Project: owner `suspended`/`deleting` gives zero rows for a member and for a requester; project `hidden_at` gives zero rows for a member; owner profile `hidden_at` with a live project still shows the project to a member but not to a stranger.
- L3 Descendants (`profile_roles`, `favourites`, `portfolio_sources`, `project_roles`, `project_members`, `collab_posts`) return zero rows to a related viewer when the owner is hidden, suspended, deleting or gone.
- L4 Requests: sender `suspended` gives the recipient zero rows; sender `deleting`/`gone` with a terminal request shows the row (E2); pending plus deleting sender is invisible; recipient states never hide the sender's own record.
- L5 Messages: sender `suspended` hides envelope and body from the counterpart; sender `deleting`/`gone` keeps envelope and body until erasure (D42/D49), then "Message removed"; block-closed conversation hides both sides.
- L6 Storage: `createSignedUrl` for post thumb/full/video/poster and project cover is refused for hidden, suspended, deleting or gone owners and for hidden posts/projects, including for related viewers; allowed for live subjects.
- L7 `recommend`: never returns a hidden, suspended, deleting, gone, reporter-hidden or blocked candidate, including viewers who have or had a relationship with it (relationship exclusion alone is not relied on).
- L8 RPCs `send_request` (all kinds), `respond_request`, `withdraw_request`, `record_feedback`, `submit_report` against each non-live counterpart return `not_found` indistinguishable from a missing id, and enqueue no outbox row.
- L9 Matrix: states {live, hidden, suspended, deleting, gone} x relationship {none, request, connection, conversation, membership} x subject type produces the committed `visibility_matrix.csv`; the test fails on any cell that differs.
- L10 Parity: for the same fixture matrix, the result of an RLS `select` as `authenticated` equals `private.subject_visible` (and `can_read_profile_row_for`); the report path cannot drift from RLS.
- L11 Transition: a counterpart that becomes suspended mid-session disappears on the next read with the same JWT, and reappears when reinstated.

**H. Reporter hide, relaunch, Realtime, signed media (F20)**
- H1 For each of the six types: after reporting, the reporter gets zero rows for the subject from REST single reads and from every list that can contain it (Search grid, profile posts/links, project lists, requests lists, thread page, Inbox preview, embedded selects); a second user still sees it (unless auto-hidden).
- H2 Relaunch and dismissal: a fresh session (new JWT) still excludes it; after the report is `dismissed` (moderation `hidden_at` cleared) others see it again and the reporter still does not; owner edits do not restore it; no RPC deletes a `reporter_hides` row (`block_user`, `unblock_user`, `clear_feedback` included).
- H3 Profile scope: reporting a profile hides the page, discovery, `recommend`, deep link and that person's projects, posts and links for the reporter; an existing conversation and request names stay readable (E1) and the chat is not closed; "Also block" then closes it.
- H4 Message (live two-client Realtime run on the local stack): after the reporter hides a message, a later `hidden_at`/`erased_at` UPDATE of that message and the body never reach the reporter's channel; new messages still do; `messages(message_bodies(body))` and direct `message_bodies` return nothing for it; gap-recovery fetch omits it; unread dot and Inbox preview ignore it; push for it is skipped with `reporter_hidden`.
- H5 Request: accept/decline/withdraw by the reporter return `not_found`; the sender's view and the request status are unchanged and the request expires normally.
- H6 Link/embed: the row is absent for the reporter; a Swift parser test shows the embed descriptor is not built for a ledger-hidden id.
- H7 Post and video: grid, profile list, viewer and `kizuki://post/<id>` deep link give not-found; new signed URLs for thumb/full/poster/video are refused; a URL minted before the report has an expiry of at most 600 s (documented window).
- H8 Ledger sync (Swift unit): given a `reporter_hides` cursor page the client purges body cache, image cache by path and in-memory lists; a second-device simulation converges on foreground/reconnect.
- H9 Lifecycle: deleting the reporter cascades their hides; purging old `reports` leaves hides intact (`report_id` set null); the deletion job removes `reporter_hides` rows whose subject is gone (B17 matrix).
- H10 Reporter hide does not leak: the owner and other users can detect no change in any response attributable to a report.
- H11 `reporter_hides` is not in the `supabase_realtime` publication (schema assertion).

## Risk class

PRIVACY.

## Cross-model review

Required (playbook rule 1: authorization; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## Resolution

Closed 2026-10-25. Design and draft migration SQL: [[2026-10-25-vf05-reports-visibility]] (amends v2 §2.3 items 5-6, §2.11, §4.2 and the v2.1 §3.3 `can_view_profile` row). No code or `supabase/` files changed.

- (a) Grant path (F18): `public.submit_report` is `SECURITY DEFINER` (no invoker exception). It calls `private.file_report`, a definer owned by `postgres` with EXECUTE revoked from every role; the callee takes no reporter or snapshot and re-derives identity, subject visibility, dedupe, the 10/day limit and the snapshot. Universal `set search_path = ''`; default privileges revoked in B02; allowlist file with a both-direction catalog test. New allowlist entries: `public.submit_report(public.report_subject_type, uuid, public.report_category, text, uuid)` and the `private.can_*` wrappers listed in section 3.4 of the design.
- (b) Liveness (F19): one visibility core applies viewer liveness, subject liveness (owner active, row not moderation-hidden), block, then reporter hide, then branches. Exactly two named exceptions: E1 hidden-name profile row for existing counterparts, E2 history of deleting/gone authors for messages and terminal requests. `recommend` and every definer RPC call the same core with no relationship branch. Parity test proves RLS and the report path agree.
- (c) Reporter hide (F20): `public.reporter_hides(reporter_id, subject_type, subject_id, report_id)` for profile, project, collab_post, request, message, portfolio_source; enforced in table policies so REST, RPCs, Realtime (per-event RLS) and signed Storage (policy on `storage.objects`) inherit it; permanent in v0, survives dismissal; client ledger sync on launch/foreground/reconnect.
- Slice split: B02 ships conventions, core, empty report tables and the strict `can_view_profile` v1; each table-creating slice writes policies against the wrappers; B10 ships writers, auto-hide and the R/H end-to-end tests.
- Knock-on edits for the orchestrator (not made here): add the B02 items above to [[013-b02-backend-backbone]] exit criteria and the R/H tests to [[021-b10-safety]]; B08 must set `notification_outbox.subject_id` to the message id; [[033-vf04-concurrency-readiness]] should absorb the `file_report` lock protocol (design section 6); [[035-vf06-push-per-device]] should add the `reporter_hidden` skip.

Needs the user (defaults taken, none blocking):
1. "Deleted user" label for suspended, deleting and gone counterparts alike (the client cannot tell them apart).
2. Reporter hide permanent with no "Show again" in v0.
3. Existing counterparts of a hidden profile can read the whole public profile row (bio, city) over REST; accept, or add a stub view later.
4. Reporting a request does not auto-decline it.

Unverified until run: hosted Supabase default privileges (G6 local, B20 staging), Realtime per-event RLS on UPDATE (H4), owner-run definer calling an ungranted definer on Postgres 17 (R1).

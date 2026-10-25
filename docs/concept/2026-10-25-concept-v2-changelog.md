---
title: Concept v2 changelog (review findings → v2)
created: 2026-10-25
tags: [project/kizuki, architecture-round, changelog]
status: complete
---

# Concept v2 changelog

Related: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v1]], [[2026-10-25-concept-v1-review-claude]], [[2026-10-25-concept-v1-review-codex]], [[2026-10-24-architecture-round-1-interview]].

One row per finding. Status: **fixed** / **partly fixed** / **rejected**. Sections refer to v2.

**Totals: 69 findings: 62 fixed, 7 partly fixed, 0 rejected.** One sub-point (C-21 a) is declined because the user accepted OD-11; the finding as a whole counts as partly fixed.

## Claude review (C-01 – C-39)

| ID | Sev | Status | Why (one line) | v2 section |
|---|---|---|---|---|
| C-01 | major | fixed | City is public (D41); person reasons can no longer use availability, work mode, pay preference or project interests; pgTAP asserts no private value leaks | 2.10, 4.2 |
| C-02 | major | fixed | `send-push` needs a server secret, takes only an outbox ID and loads everything else itself; user JWT is rejected | 2.5, 2.9 |
| C-03 | major | fixed | No webhook in migrations; Vault holds the per-environment URL and secret; CI greps migrations for URLs and keys | 2.5, 2.9, 3 |
| C-04 | major | fixed | Global lock order, row locks and an atomic conditional seat claim with a unique backstop; race tests | 4.5, 8.4 |
| C-05 | major | fixed | Accept re-validates expiry, accounts, block, project, seat ownership; deletion withdraws pending requests first | 4.5, 4.7 |
| C-06 | major | fixed | Partial unique index on open conversations; a new accept after unblock creates a new generation | 2.6, 4.2 |
| C-07 | major | fixed | Blocked side always gets `not_found`; blocked conversations are hidden, so no "closed" banner | 2.11 |
| C-08 | major | fixed | `discoverable` only filters `recommend`; profile visibility includes counterparts via `can_view_profile` | 2.10, 4.2 |
| C-09 | major | fixed | `show_favourites` moved to `profiles` (public flag) read through a boolean helper; one name | 2.13, 4.2 |
| C-10 | major | fixed | Token is the primary key, reassigned on register, unregistered before sign-out and account switch | 2.9, 2.8 |
| C-11 | major | fixed | Moderation column per subject type, definer trigger, only qualifying reporters count (anti-brigading) | 2.11 |
| C-12 | major | fixed | No-taste viewers or candidates get neutral taste and no band; admission by Stage 0 + threshold; golden fixture | 2.10 |
| C-13 | major | partly fixed | Test layers and ownership defined: live suites on Linux CI, recorded contracts replayed on macOS, manual live pass; a live iOS run in CI is still not possible without Docker on macOS | 8.4 |
| C-14 | major | fixed | One generator, two loaders; staging loader is ref-pinned, uses Admin + Storage APIs, checks the staging marker | 3 |
| C-15 | major | fixed | Production refused unconditionally in v0 by app config and validator; exact staging allowlist; single remote gateway | 3 |
| C-16 | major | partly fixed | Auth config goes through the gateway with a dashboard fallback; staging plan (pause, breach check) is now OD-16; `config push` support unverified | 3, 7.2 |
| C-17 | major | fixed | Added complete/renew/update_published/add/remove role RPCs; invariants enforced on every write | 2.4, 4.6 |
| C-18 | major | partly fixed | Cut logging, mix + O8, exposure floor, bonus, follow-ups, reopen, trigram, "For you", third bucket; kept per-card facet weights (needed by `N-ALG` maths), unread dot, covers (in the existing bucket), renew (accepted OD-13) | 2.10, 6 |
| C-19 | major | fixed | K01 is a thin shell; wave 0 freezes only core-loop contracts; later slices extend with a contract review | 8.1, 8.2 |
| C-20 | major | fixed | D42 purge key (`sender_deleted_at`) and daily erasure job; report evidence retention defined | 4.7, 2.5 |
| C-21 | major | partly fixed | (b) Terms + Community Guidelines added (K04, K15); (c) 18+ rating in K20; (a) hold-for-review declined: user accepted OD-11 "report + auto-hide + daily review" (interview, "accepted by default") | 2.11, 8.2 |
| C-22 | minor | fixed | Staging marked "not yet buildable" until URL and key are set | 3 |
| C-23 | minor | fixed | OD-5 removed; D43 applied, `Staging.xcconfig` change is in K03 | 3, 8.2 |
| C-24 | minor | fixed | Terms/18+ is the first step; auth-only `delete-account` and abandoned-sign-up purge ship with the gate in K04 | 2.8, 8.2 |
| C-25 | minor | fixed | Pair key covers both directions; `nulls not distinct`; 90-day decline window in RPC; pending never survives project deletion | 4.4, 4.3 |
| C-26 | minor | fixed | Readiness levels copied from `N-ONB`; one `missing_fields` function shared with RPCs; `email_not_verified` scope noted | 4.8 |
| C-27 | minor | fixed | Explicit schema usage and execute grants on named helpers; definer functions owned by the table owner; pgTAP checks | 2.3 |
| C-28 | minor | fixed | Password recovery by 6-digit code, recovery template, recovery root phase, live test | 2.8 |
| C-29 | minor | fixed | FIG-V states the copy keeps the same node IDs and captured 64 frames by those IDs; screen list cites the copy | header, 9 |
| C-30 | minor | fixed | `last_active_on` moved to private settings, written by `touch_activity()` from RPCs and the message trigger | 2.10, 4.2 |
| C-31 | minor | fixed | Fit reasons removed from request detail; foreground banner suppressed client-side; diagram note fixed | 5.3, 2.9, 10.2 |
| C-32 | minor | fixed | One project machine: no reopen, renew only from past(expired), closed → past(completed) included in diagram | 4.6, 10.3 |
| C-33 | minor | fixed | Seed volumes restated for direct chats only and the v0 account states | 11 |
| C-34 | minor | fixed | TestSupport sources wrapped in `#if DEBUG`; release-build symbol check | 2.2 |
| C-35 | minor | fixed | Report RPC writes a persistent hide; snapshot built from the caller-visible projection | 2.11 |
| C-36 | minor | fixed | Block removes memberships between the pair and reopens seats on published projects | 2.11 |
| C-37 | minor | fixed | CHECK constraints bind avatar, cover and photo paths to the owner's prefix | 2.7 |
| C-38 | minor | fixed | Marked as a design deviation and logged | 2.10, Appendix A 46 |
| C-39 | minor | fixed | Cost table added; unknown values marked TBD/unverified and tied to OD-15/16 | 11 |

## Codex review (X-01 – X-30)

| ID | Sev | Status | Why (one line) | v2 section |
|---|---|---|---|---|
| X-01 | blocker | fixed | Kind-specific authorization and seat filler (sender for join, recipient for invite); full re-validation at accept incl. deadline and moderation | 4.5 |
| X-02 | blocker | fixed | Lock order (profiles → pair → project → seat → request → conversation), conditional seat claim, message trigger locks the conversation; two-connection tests for every listed pair | 4.5, 2.6, 8.4 |
| X-03 | major | fixed | Report RPC checks visibility as the caller; evidence and reviewer notes in a private table | 2.11 |
| X-04 | major | fixed | 10-min TTL stated as the revocation window; public-avatar exception stated; per-user scoped cache with purge events; signed-URL tests | 2.7 |
| X-05 | blocker | fixed | `deleting` state freezes writes; `caller_ok()` refuses stale JWTs across PostgREST, RPCs, Storage, Realtime; global refresh-token revocation; resumable job | 4.7, 2.3 |
| X-06 | blocker | fixed | Server-secret authentication, outbox ID only, forged fields ignored, user JWT rejected; Deno tests | 2.5, 2.9 |
| X-07 | major | fixed | One owner per token, environment bound to build config, unlink on sign-out/switch, preferences and block re-checked at delivery | 2.9 |
| X-08 | major | fixed | Outbox lease/claim with `skip locked`, attempts, backoff, dead state, dedupe key, collapse ID, cron drain | 2.9 |
| X-09 | major | fixed | `op_id` result replay for retryable RPCs; replace-and-recompute taste; one onboarding draft; accepted pairs blocked from new pending | 2.4, 2.13, 4.4 |
| X-10 | major | fixed | Moderation column and enforcement per subject incl. messages (Realtime via RLS), requests, links; suspension via `caller_ok()` | 2.11 |
| X-11 | major | fixed | Conversation generations; blocked history hidden from both, not reused | 2.6 |
| X-12 | major | fixed | Every FK's delete behaviour listed; pending terminalized first; populated-graph test | 4.3 |
| X-13 | major | fixed | Code exchange + `/auth/revoke` at deletion from a fresh Apple re-auth; manual fallback only without a code; mocked until D39 | 4.7 |
| X-14 | major | partly fixed | Spike first, then disclose-and-Undo contract; whether Supabase can prevent the link is unknown (OD-17) | 2.8, 7.2 |
| X-15 | major | fixed | Profile fields, explicit `refreshProfile()`, derived root phases incl. recovery, `SessionScope` task and channel teardown | 2.2 |
| X-16 | major | fixed | Server-owned `seq`/`created_at`, subscribe-then-fetch with 5-min overlap and id dedupe, `(created_at, id)` cursor | 2.6 |
| X-17 | major | fixed | Boolean definer helpers (incl. `is_participant`, `favourites_visible`), grants, ownership, recursion tests | 2.3, 4.2 |
| X-18 | major | fixed | Separate display and matching consents for favourites; rarity population defined; consent-off applies on next call | 2.13 |
| X-19 | major | fixed | Readiness levels; taste skippable (zero selections); `flexible_timing` added | 4.8, 2.13, 4.2 |
| X-20 | major | fixed | Cosine mapping, shrinkage, bridge-only cross-realm, zero-norm and zero-denominator rules, common thread for adjacent, golden examples | 2.10 |
| X-21 | major | fixed | Exact staging host in app + validator, Production refused, gateway with link-state and marker checks; empty production fails the marker | 3 |
| X-22 | major | fixed | Purpose strings in K05, Push capability in K17, Apple entitlement in K18; only archive-only items stay in K20 | 2.2, 8.1 |
| X-23 | blocker | fixed | Re-sliced: conversations schema in K08a with accept; draft creation moves into K06; taste uses a dirty flag so requests do not need the taste store | 8.2, 2.13 |
| X-24 | blocker | partly fixed | Escape hatch removed and every locked feature is a v0 exit criterion; wave 0 freezes core-loop contracts only; slice size is reduced but still large (Risk 1) | 6, 8.1, 7.1 |
| X-25 | blocker | fixed | D42 implemented: `sender_deleted_at`, nullable body with `erased_at`, daily erasure job, UI copy, time-travel test | 4.7, 4.2 |
| X-26 | major | fixed | Recovery by code end to end, `passwordRecovery` handled, no redirect URLs needed | 2.8 |
| X-27 | major | fixed | Eligibility gate first and server-enforced; deletion available in the same slice; abandoned sign-ups purged | 2.8, 8.2 |
| X-28 | major | partly fixed | Runner ownership for pgTAP, races, live Realtime/Storage/function suites and provider smoke defined; live iOS against a backend stays a manual pass | 8.4 |
| X-29 | minor | fixed | Crew, public city, one bundle ID applied throughout; removed from open decisions | throughout, 7.2 |
| X-30 | minor | fixed | Inventory regenerated with slice IDs; column-level UPDATE grants specified | 2.3, 2.4 |

## Other inputs applied

- D40/D44 "Crew" (2.2, 5.3, 9, 10); D41 public city (4.2, 2.10); D42 retention (4.7); D43 one app (3); accepted OD-1, 2, 3, 6, 8, 9, 10, 11, 12, 13 (throughout); D45 agent rotation (8.1).
- Visual pass: request form `1480:4806` keeps role, time, notes (4.4, 5.3, 9); Suki chooser "Get discovered / Create a project / Post a collab" (5.4, 9); two-option goal screen + Start/Join follow-up (5.1, 9); star ratings and comments out (5.2, 9); Skip removed from account creation (5.1); notifications alert on the location frame noted (9).

## Round 2: verification findings F01–F26 → v2.1, tickets, accepted risks

Source: [[2026-10-25-concept-v2-verification-codex]] (36 verified-fixed, 33 partly, 26 new findings). Amendment: [[2026-10-25-architecture-concept-v2.1]]. Tickets on [[2026-10-25-wayfinder-map]]. No third review round (playbook rule 4).

| ID | Sev | Outcome | Where / reason |
|---|---|---|---|
| F01 | major | resolved in v2.1 + ticket 040 | v2.1 §5.1 people reason allowlist, generic `beyond_your_city`; allowlist pgTAP in VF11 |
| F02 | blocker | resolved in v2.1 | v2.1 §1: `crew_connections` generations, guard scoped to active connection, tests T1–T11; proof in ticket 018 (B07) |
| F03 | major | ticket 033 (VF04) | Multi-party lock sets, profile-lock upgrades, filler readiness re-check |
| F04 | blocker | resolved in v2.1 | v2.1 §2: envelope/body split, envelopes-only Realtime, `send_message` RPC, tests M1–M10; proof in ticket 019 (B08) |
| F05 | blocker | resolved in v2.1 | v2.1 §3.3–3.4: schema-before-consumer rule, versioned intermediate contracts table, prefix proof per slice, re-sliced B01–B21; Apple items deferred checklist in B20 |
| F06 | major | ticket 035 (VF06) | Per-device deliveries, fenced leases |
| F07 | major | ticket 036 (VF07) | Quiescence and Storage reconciliation |
| F08 | major | ticket 037 (VF08) | First-deploy bootstrap, runtime `.production` refusal; gates B03 |
| F09 | major | resolved in v2.1 + ticket 038; accepted risk for CI | v2.1 §3.5 requires a live Swift run for B04–B09 on the now-working local stack. **Accepted risk:** the live run is a local merge gate, not a CI job, because hosted macOS runners cannot host the stack (unverified, documented) |
| F10 | major | resolved in v2.1 + ticket 040 | v2.1 §4.2 availability public in `profiles`, work mode private |
| F11 | minor | resolved in v2.1 + ticket 041 | v2.1 §4.3–4.4 copy and accept → chat; prototype update in VF12 |
| F12 | major | resolved in v2.1 | v2.1 §1.5 Remove from Crew contract and tests |
| F13 | major | resolved in v2.1 (partly) + ticket 041; accepted risk | v2.1 §4.5: video is in v0 with limits, `user-video` bucket, no people results. Open product questions in VF12. **Accepted risk:** real video duration is not verified server-side; the size cap bounds abuse |
| F14 | minor | resolved in v2.1 + ticket 041 | v2.1 §4.6 acceptance criteria; vector originals swap in VF12 |
| F15 | major | resolved in v2.1 + ticket 042 | v2.1 §4.1 applies D46–D49 (D49 erase on report closure); release gates in VF13 |
| F16 | minor | resolved in v2.1 | v2.1 §3.2 prototype baseline and module names |
| F17 | minor | resolved in v2.1 | v2.1 §3.4: 21 slices, tickets 012–032 |
| F18 | major | ticket 034 (VF05) | Report invoker/definer grant path |
| F19 | major | ticket 034 (VF05) | Subject-liveness predicate first; v2.1 §3.3 already orders it in `can_view_profile` v2 |
| F20 | major | ticket 034 (VF05) | Persisted reporter hides for all subject types |
| F21 | major | ticket 036 (VF07) | Remaining FK outcomes and pair keys |
| F22 | major | ticket 036 (VF07) | Durable Apple revoke credential across code exchange |
| F23 | major | ticket 039 (VF10) | Chat gap recovery beyond the 5-minute overlap |
| F24 | minor | resolved in v2.1 (rule) + ticket 039 (fixtures) | v2.1 §5.2 band null without bridged facet evidence; summary corrected |
| F25 | major | ticket 033 (VF04) | Atomic `op_id` reservation with parameter hash |
| F26 | minor | resolved in v2.1 | v2.1 §4.7 Get discovered placement and rationale |

Totals: 15 resolved in v2.1 (incl. all three blockers; several also have an implementation-test ticket), 11 carried as tickets only, 2 accepted risks attached to resolved findings (F09 CI scope, F13 server-side duration). The 33 "partly" original findings are covered by the same tickets (VR "Follow-up tickets" mapping).

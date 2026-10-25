---
id: 013
title: "B02 Backend backbone + test harness"
labels: [wayfinder:build]
status: open
blocked_by: []
assignee:
created: 2026-10-25
---

# B02 Backend backbone + test harness

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Create the shared schema, helpers, grants and test harness every later slice builds on.

## Concept references

v2 §2.3, §4.1–4.2; v2.1 §3.3 (versioned contracts), §3.4 (B02), §4.2 (availability public).

## Exit criteria (tests that prove it)

- Enums, taxonomies, `private` schema, `caller_ok`, `is_blocked`, `can_view_profile` v1, explicit grants; `blocks`, `notification_outbox`, `op_results` (atomic reservation per VF04), environment marker table, `legal_acceptances`, `blocked_terms`, profile/settings extensions (public city and availability, private work mode).
- pgTAP: helpers, grants, policy recursion, raw-REST visibility of public vs private profile fields.
- CI `backend` job: pgTAP, Python two-connection race harness (one sample race), Deno runner, migration grep (no URLs/keys/user inserts), prefix check.
- `scripts/test-prefix.sh B02` passes; seed generator + local loader produce a working local seed.
- `scripts/supabase-local.sh start` succeeds locally (closes ticket 005).

## Risk class

PRIVACY (definer helpers, RLS, grants).

## Cross-model review

Required (playbook rule 1: authorization core; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## From VF05 (2026-10-25)

See [[2026-10-25-vf05-reports-visibility]].
- Ship: definer/search_path conventions, revoked default privileges, visibility core, empty report tables, strict `can_view_profile` v1, allowlist catalog test (G group).
- Decision #68: hidden-profile exception E1 must return a name stub (no bio/city), via a stub projection.

## From VF08 (2026-10-25)

See [[2026-10-25-vf08-env-bootstrap]]. The environment marker is **not** a B02 migration: remove "environment marker table" from this slice. It lives in `supabase/bootstrap/env_marker.sql` (owned by [[014-b03-environment-pinning]]); `scripts/supabase-local.sh reset` applies the local marker after `db reset`. B02's migration grep must also reject `kizuki_env`.

## From PR #2 review round 2 (2026-10-26)

See [[2026-10-25-pr2-b01-review-claude]].
- F-03: extend the profile select and recorded contract once B02 tables exist.

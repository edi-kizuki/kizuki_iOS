---
id: 021
title: "B10 Safety"
labels: [wayfinder:build]
status: open
blocked_by: [019,020,033,034]
assignee:
created: 2026-10-25
---

# B10 Safety

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Full block, report, moderation states and auto-hide across every live surface.

## Concept references

v2 §2.11; v2.1 §1.5–1.6, §2.4; ticket 034 (VF05).

## Exit criteria (tests that prove it)

- Full `block_user` side effects (memberships, likes), reports split with invoker/definer grants per VF05, moderation states incl. message envelope `hidden_at`, auto-hide with qualifying reporters, persisted reporter hides for every subject type.
- Visibility matrix both directions on every read path so far; T1, T2, T8 and M2–M5 re-run.
- Live block and report pass on profile, project, request and message.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

PRIVACY.

## Cross-model review

Required (playbook rule 1: authorization, 3+ files; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

## From VF05 (2026-10-25)

See [[2026-10-25-vf05-reports-visibility]].
- Ship report writers (`submit_report` → `private.file_report`), auto-hide, and end-to-end R and H test groups.

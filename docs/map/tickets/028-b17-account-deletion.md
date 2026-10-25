---
id: 028
title: "B17 Full account deletion + retention"
labels: [wayfinder:build]
status: open
blocked_by: [022,027,033,036,042]
assignee:
created: 2026-10-25
---

# B17 Full account deletion + retention

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Deletion that finishes under races and crashes, removes all files, revokes Apple tokens and applies D42/D49 retention.

## Concept references

v2 §4.3, §4.7; v2.1 §1.5, §2.2 (erasure), §4.1 (D49); ticket 036 (VF07).

## Exit criteria (tests that prove it)

- Storage purge with quiescence, refresh-token revocation, job-secret resume, Apple credential progress per VF07.
- Complete FK matrix; populated-graph deletion test; paused-upload and crash-point tests; T10.
- Erasure job: D42 day 30 and D49 report-closure cases (test clock).
- Live: delete account from Settings, other user sees "Deleted user".
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

DELETE + AUTH.

## Cross-model review

Required (playbook rule 1: deleting data and auth; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

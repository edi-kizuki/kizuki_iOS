---
id: 027
title: "B16 Settings, legal, support"
labels: [wayfinder:build]
status: open
blocked_by: [021]
assignee:
created: 2026-10-25
---

# B16 Settings, legal, support

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Live settings pages, legal and support content, sign-out with token unlink.

## Concept references

v2 §2.11 (Apple 1.2 coverage); v2.1 §4.1.

## Exit criteria (tests that prove it)

- Notification preferences, privacy & safety (blocked list, matching toggle), legal pages (Terms, Community Guidelines, Privacy, YouTube ToS), support contact (OD-15), sign-out.
- Live: preferences persist and are read by the server.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

3+ files.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

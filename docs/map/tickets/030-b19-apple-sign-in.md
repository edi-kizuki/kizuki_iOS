---
id: 030
title: "B19 Sign in with Apple"
labels: [wayfinder:build]
status: open
blocked_by: [015,028,006]
assignee:
created: 2026-10-25
---

# B19 Sign in with Apple

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Apple sign-in with immediate disclosure and Undo of automatic identity linking (D47).

## Concept references

v2 §2.8; v2.1 §4.1 (D47).

## Exit criteria (tests that prove it)

- Nonce flow, entitlement, first-sign-in name capture, link disclosure + `unlinkIdentity` Undo, authorization code handed to deletion.
- Unit tests for nonce and disclosure logic; device sign-in once ticket 006 is done.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

AUTH.

## Cross-model review

Required (playbook rule 1: auth; changes 3+ files). Reviewer is the other model family (D45); max two review rounds.

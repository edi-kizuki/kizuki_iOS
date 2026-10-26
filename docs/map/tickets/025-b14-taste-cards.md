---
id: 025
title: "B14 Taste cards + pairwise"
labels: [wayfinder:build]
status: open
blocked_by: [020,022,039]
assignee:
created: 2026-10-25
---

# B14 Taste cards + pairwise

Map: [[2026-10-25-wayfinder-map]]. Concept: [[2026-10-25-architecture-concept-v2]], [[2026-10-25-architecture-concept-v2.1]].

## Goal

Replay-safe taste capture feeding the recommender.

## Concept references

v2 §2.13; v2.1 §3.3 (`recompute_taste` v2), §5.2.

## Exit criteria (tests that prove it)

- Taste tables, placeholder art in `taste-cards`, `submit_taste` (replace semantics, skippable), `recompute_taste` v2, taste component in `recommend`.
- pgTAP maths against hand-computed values; replay yields identical facets; VF10 band edge goldens.
- Live: onboarding taste steps change Home ordering for a seeded viewer.
- Every slice: tests start from an empty local DB with migrations up to this slice only (`scripts/test-prefix.sh <slice>`); fixture UI tests stay green; new UGC surfaces have Report; user-linked tables extend `private.freeze_account` and the FK matrix (v2.1 §3.3).

## Risk class

3+ files.

## Cross-model review

Required (playbook rule 1: changes 3+ files). Reviewer is the other model family (D45); max two review rounds.
